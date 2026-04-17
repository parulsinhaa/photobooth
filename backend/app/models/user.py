# backend/app/models/user.py
import uuid
from enum import Enum
from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime, Enum as SAEnum, Integer, Text, ForeignKey, Float
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from ..core.database import Base


class SubscriptionTier(str, Enum):
    FREE = "free"
    PRO = "pro"
    PREMIUM = "premium"


class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username = Column(String(50), unique=True, nullable=False, index=True)
    email = Column(String(255), unique=True, nullable=True, index=True)
    phone = Column(String(20), unique=True, nullable=True, index=True)
    phone_country_code = Column(String(10), nullable=True)
    full_name = Column(String(100), nullable=True)
    avatar_url = Column(String(500), nullable=True)
    bio = Column(String(300), nullable=True)
    firebase_uid = Column(String(128), unique=True, nullable=True, index=True)

    # Subscription
    subscription_tier = Column(SAEnum(SubscriptionTier), default=SubscriptionTier.FREE, nullable=False)
    subscription_expires_at = Column(DateTime, nullable=True)
    subscription_auto_renew = Column(Boolean, default=False)

    # Stats
    total_photos = Column(Integer, default=0)
    total_strips = Column(Integer, default=0)
    total_orders = Column(Integer, default=0)
    followers_count = Column(Integer, default=0)
    following_count = Column(Integer, default=0)

    # Settings
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    is_private = Column(Boolean, default=False)
    allow_messages = Column(Boolean, default=True)
    notifications_enabled = Column(Boolean, default=True)
    country_code = Column(String(5), default="IN")
    currency = Column(String(5), default="INR")

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_seen_at = Column(DateTime, nullable=True)

    # Relationships
    payments = relationship("Payment", back_populates="user")
    orders = relationship("Order", back_populates="user")
    media = relationship("Media", back_populates="user")
    strips = relationship("PhotoStrip", back_populates="user")


# backend/app/models/payment.py
class PaymentStatus(str, Enum):
    PENDING = "pending"
    COMPLETED = "completed"
    FAILED = "failed"
    REFUNDED = "refunded"


class Payment(Base):
    __tablename__ = "payments"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    razorpay_order_id = Column(String(100), unique=True, nullable=True)
    razorpay_payment_id = Column(String(100), unique=True, nullable=True)
    razorpay_signature = Column(String(500), nullable=True)
    refund_id = Column(String(100), nullable=True)
    amount = Column(Integer, nullable=False)  # in paise
    currency = Column(String(10), default="INR")
    plan = Column(String(50), nullable=False)
    status = Column(SAEnum(PaymentStatus), default=PaymentStatus.PENDING)
    created_at = Column(DateTime, default=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)
    user = relationship("User", back_populates="payments")


class Order(Base):
    __tablename__ = "orders"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    strip_id = Column(UUID(as_uuid=True), ForeignKey("photo_strips.id"), nullable=True)

    # Print details
    print_size = Column(String(20), nullable=False)  # "4x6", "5x7", "wallet"
    quantity = Column(Integer, default=1)
    paper_type = Column(String(50), default="glossy")  # glossy, matte, luster

    # Pricing
    unit_price = Column(Integer, nullable=False)  # in paise
    total_price = Column(Integer, nullable=False)
    currency = Column(String(10), default="INR")
    discount_pct = Column(Integer, default=0)

    # Delivery
    delivery_name = Column(String(100), nullable=False)
    delivery_phone = Column(String(20), nullable=False)
    delivery_address = Column(Text, nullable=False)
    delivery_city = Column(String(100), nullable=False)
    delivery_state = Column(String(100), nullable=False)
    delivery_pincode = Column(String(20), nullable=False)
    delivery_country = Column(String(100), default="India")

    # Status
    status = Column(String(30), default="pending")  # pending, confirmed, printing, shipped, delivered
    tracking_id = Column(String(100), nullable=True)
    estimated_delivery = Column(DateTime, nullable=True)
    payment_id = Column(UUID(as_uuid=True), ForeignKey("payments.id"), nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="orders")


class PhotoStrip(Base):
    __tablename__ = "photo_strips"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    template_id = Column(String(50), nullable=False)
    title = Column(String(100), nullable=True)

    # Storage
    s3_key = Column(String(500), nullable=False)
    thumbnail_key = Column(String(500), nullable=True)
    cdn_url = Column(String(500), nullable=True)
    thumbnail_url = Column(String(500), nullable=True)

    # Metadata
    photo_count = Column(Integer, nullable=False)
    width = Column(Integer, nullable=True)
    height = Column(Integer, nullable=True)
    filters_applied = Column(Text, nullable=True)  # JSON
    is_public = Column(Boolean, default=False)
    view_count = Column(Integer, default=0)
    likes_count = Column(Integer, default=0)

    created_at = Column(DateTime, default=datetime.utcnow)
    user = relationship("User", back_populates="strips")


class Media(Base):
    __tablename__ = "media"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    media_type = Column(String(20), nullable=False)  # photo, video, strip
    s3_key = Column(String(500), nullable=False)
    cdn_url = Column(String(500), nullable=True)
    file_size = Column(Integer, nullable=True)
    width = Column(Integer, nullable=True)
    height = Column(Integer, nullable=True)
    duration_seconds = Column(Float, nullable=True)  # for videos
    created_at = Column(DateTime, default=datetime.utcnow)
    user = relationship("User", back_populates="media")
