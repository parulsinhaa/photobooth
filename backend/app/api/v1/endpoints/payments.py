# backend/app/api/v1/endpoints/payments.py
import hmac
import hashlib
import razorpay
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from datetime import datetime, timedelta
from typing import Optional
import logging

from ....core.config import settings
from ....core.database import get_db
from ....core.security import get_current_user
from ....models.user import User, SubscriptionTier
from ....models.payment import Payment, PaymentStatus
from ....schemas.payment import (
    CreateOrderRequest,
    CreateOrderResponse,
    VerifyPaymentRequest,
    PaymentWebhookPayload,
)
from ....services.notification_service import NotificationService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/payments", tags=["payments"])

# Initialize Razorpay client
razorpay_client = razorpay.Client(
    auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET)
)

# UPI ID for receiving payments
MERCHANT_UPI_ID = "parulsinhaa5@okaxis"
MERCHANT_NAME = "Photo Booth"


@router.post("/create-order", response_model=CreateOrderResponse)
async def create_payment_order(
    request: CreateOrderRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a Razorpay order for subscription or print purchase."""

    # Validate amount
    plan_amounts = {
        "pro": 9900,       # Rs 99 in paise
        "premium": 29900,  # Rs 299 in paise
        "filter": 900,     # Rs 9 per filter
        "print": None,     # Dynamic pricing
    }

    plan = request.plan.lower()
    if plan not in plan_amounts:
        raise HTTPException(status_code=400, detail="Invalid plan")

    expected_amount = plan_amounts.get(plan)
    if expected_amount and request.amount != expected_amount:
        raise HTTPException(status_code=400, detail="Amount mismatch")

    try:
        # Create Razorpay order
        order_data = {
            "amount": request.amount,
            "currency": request.currency,
            "receipt": f"pb_{current_user.id}_{int(datetime.now().timestamp())}",
            "payment_capture": 1,
            "notes": {
                "user_id": str(current_user.id),
                "plan": plan,
                "period": request.period,
                "upi_id": MERCHANT_UPI_ID,
            },
        }

        razorpay_order = razorpay_client.order.create(data=order_data)

        # Save pending payment to DB
        payment = Payment(
            user_id=current_user.id,
            razorpay_order_id=razorpay_order["id"],
            amount=request.amount,
            currency=request.currency,
            plan=plan,
            status=PaymentStatus.PENDING,
        )
        db.add(payment)
        await db.commit()

        return CreateOrderResponse(
            razorpay_order_id=razorpay_order["id"],
            amount=request.amount,
            currency=request.currency,
            key_id=settings.RAZORPAY_KEY_ID,
        )

    except razorpay.errors.BadRequestError as e:
        logger.error(f"Razorpay order creation failed: {e}")
        raise HTTPException(status_code=400, detail="Payment initialization failed")


@router.post("/verify")
async def verify_payment(
    request: VerifyPaymentRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Verify Razorpay payment signature and activate subscription."""

    # Verify signature
    expected_signature = hmac.new(
        settings.RAZORPAY_KEY_SECRET.encode(),
        f"{request.razorpay_order_id}|{request.razorpay_payment_id}".encode(),
        hashlib.sha256,
    ).hexdigest()

    if expected_signature != request.razorpay_signature:
        logger.warning(
            f"Payment signature mismatch for user {current_user.id}, "
            f"payment {request.razorpay_payment_id}"
        )
        raise HTTPException(status_code=400, detail="Invalid payment signature")

    # Verify payment with Razorpay API
    try:
        payment_data = razorpay_client.payment.fetch(request.razorpay_payment_id)
        if payment_data["status"] != "captured":
            raise HTTPException(status_code=400, detail="Payment not captured")
    except Exception as e:
        logger.error(f"Payment fetch failed: {e}")
        raise HTTPException(status_code=400, detail="Payment verification failed")

    # Update payment record
    stmt = select(Payment).where(
        Payment.razorpay_order_id == request.razorpay_order_id,
        Payment.user_id == current_user.id,
    )
    result = await db.execute(stmt)
    payment = result.scalar_one_or_none()

    if not payment:
        raise HTTPException(status_code=404, detail="Payment record not found")

    payment.razorpay_payment_id = request.razorpay_payment_id
    payment.razorpay_signature = request.razorpay_signature
    payment.status = PaymentStatus.COMPLETED
    payment.completed_at = datetime.utcnow()

    # Activate subscription
    tier_map = {
        "pro": SubscriptionTier.PRO,
        "premium": SubscriptionTier.PREMIUM,
    }

    if request.plan in tier_map:
        current_user.subscription_tier = tier_map[request.plan]
        current_user.subscription_expires_at = datetime.utcnow() + timedelta(days=30)
        current_user.subscription_auto_renew = True

    await db.commit()

    # Background tasks
    background_tasks.add_task(
        NotificationService.send_payment_confirmation,
        user=current_user,
        payment=payment,
    )

    return {
        "success": True,
        "message": f"{request.plan.title()} plan activated successfully",
        "expires_at": current_user.subscription_expires_at.isoformat(),
    }


@router.post("/razorpay-callback")
async def razorpay_webhook(
    request: dict,
    db: AsyncSession = Depends(get_db),
):
    """Razorpay webhook for server-side payment events."""

    # Verify webhook signature
    webhook_signature = request.get("razorpay_signature")
    webhook_secret = settings.RAZORPAY_WEBHOOK_SECRET

    if webhook_secret and webhook_signature:
        payload = str(request).encode()
        expected = hmac.new(
            webhook_secret.encode(), payload, hashlib.sha256
        ).hexdigest()
        if expected != webhook_signature:
            raise HTTPException(status_code=400, detail="Invalid webhook signature")

    event = request.get("event")
    payload = request.get("payload", {})

    if event == "payment.captured":
        payment_entity = payload.get("payment", {}).get("entity", {})
        order_id = payment_entity.get("order_id")

        if order_id:
            stmt = update(Payment).where(
                Payment.razorpay_order_id == order_id
            ).values(status=PaymentStatus.COMPLETED)
            await db.execute(stmt)
            await db.commit()

    elif event == "payment.failed":
        payment_entity = payload.get("payment", {}).get("entity", {})
        order_id = payment_entity.get("order_id")

        if order_id:
            stmt = update(Payment).where(
                Payment.razorpay_order_id == order_id
            ).values(status=PaymentStatus.FAILED)
            await db.execute(stmt)
            await db.commit()

    return {"status": "ok"}


@router.post("/refund/{payment_id}")
async def initiate_refund(
    payment_id: str,
    amount: Optional[int] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Initiate a refund for a payment."""

    # Verify payment belongs to user
    stmt = select(Payment).where(
        Payment.razorpay_payment_id == payment_id,
        Payment.user_id == current_user.id,
        Payment.status == PaymentStatus.COMPLETED,
    )
    result = await db.execute(stmt)
    payment = result.scalar_one_or_none()

    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")

    # Check refund eligibility (within 7 days)
    if payment.completed_at and (datetime.utcnow() - payment.completed_at).days > 7:
        raise HTTPException(
            status_code=400,
            detail="Refund period expired (7 days from purchase)"
        )

    try:
        refund_data = {"amount": amount or payment.amount}
        refund = razorpay_client.payment.refund(payment_id, refund_data)

        payment.status = PaymentStatus.REFUNDED
        payment.refund_id = refund.get("id")

        # Downgrade subscription
        current_user.subscription_tier = SubscriptionTier.FREE
        current_user.subscription_expires_at = None

        await db.commit()

        return {
            "success": True,
            "refund_id": refund.get("id"),
            "amount": refund.get("amount"),
            "message": "Refund initiated. Will reflect in 5-7 business days.",
        }

    except Exception as e:
        logger.error(f"Refund failed: {e}")
        raise HTTPException(status_code=500, detail="Refund initiation failed")


@router.get("/history")
async def get_payment_history(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get user's payment history."""
    stmt = select(Payment).where(
        Payment.user_id == current_user.id
    ).order_by(Payment.created_at.desc())
    result = await db.execute(stmt)
    payments = result.scalars().all()

    return {
        "payments": [
            {
                "id": str(p.id),
                "amount": p.amount / 100,  # Convert paise to rupees
                "currency": p.currency,
                "plan": p.plan,
                "status": p.status.value,
                "created_at": p.created_at.isoformat(),
                "completed_at": p.completed_at.isoformat() if p.completed_at else None,
            }
            for p in payments
        ]
    }
