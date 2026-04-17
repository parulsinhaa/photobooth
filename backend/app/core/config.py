# backend/app/core/config.py
from pydantic_settings import BaseSettings
from typing import List
import os


class Settings(BaseSettings):
    # App
    APP_NAME: str = "Photo Booth API"
    DEBUG: bool = os.getenv("DEBUG", "false").lower() == "true"
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-super-secret-key-change-in-production")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Database
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        "postgresql+asyncpg://photobooth:password@localhost:5432/photobooth_db"
    )

    # CORS
    ALLOWED_ORIGINS: List[str] = [
        "https://photobooth.app",
        "https://www.photobooth.app",
        "http://localhost:3000",
        "http://localhost:8080",
        "*",  # Remove in production!
    ]

    # AWS S3
    AWS_ACCESS_KEY_ID: str = os.getenv("AWS_ACCESS_KEY_ID", "")
    AWS_SECRET_ACCESS_KEY: str = os.getenv("AWS_SECRET_ACCESS_KEY", "")
    AWS_REGION: str = os.getenv("AWS_REGION", "ap-south-1")
    S3_BUCKET_NAME: str = os.getenv("S3_BUCKET_NAME", "photobooth-media")
    CDN_BASE_URL: str = os.getenv("CDN_BASE_URL", "https://cdn.photobooth.app")

    # Firebase
    FIREBASE_CREDENTIALS_PATH: str = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase-credentials.json")
    FIREBASE_PROJECT_ID: str = os.getenv("FIREBASE_PROJECT_ID", "photobooth-app")

    # Razorpay
    RAZORPAY_KEY_ID: str = os.getenv("RAZORPAY_KEY_ID", "rzp_live_xxx")
    RAZORPAY_KEY_SECRET: str = os.getenv("RAZORPAY_KEY_SECRET", "")
    RAZORPAY_WEBHOOK_SECRET: str = os.getenv("RAZORPAY_WEBHOOK_SECRET", "")

    # UPI
    UPI_ID: str = "parulsinhaa5@okaxis"
    UPI_NAME: str = "Photo Booth"

    # Redis (for rate limiting, caching, WebSocket)
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://localhost:6379/0")

    # Email
    SMTP_HOST: str = os.getenv("SMTP_HOST", "smtp.gmail.com")
    SMTP_PORT: int = int(os.getenv("SMTP_PORT", "587"))
    SMTP_USER: str = os.getenv("SMTP_USER", "")
    SMTP_PASSWORD: str = os.getenv("SMTP_PASSWORD", "")
    FROM_EMAIL: str = os.getenv("FROM_EMAIL", "noreply@photobooth.app")

    # SMS (Twilio)
    TWILIO_ACCOUNT_SID: str = os.getenv("TWILIO_ACCOUNT_SID", "")
    TWILIO_AUTH_TOKEN: str = os.getenv("TWILIO_AUTH_TOKEN", "")
    TWILIO_FROM_NUMBER: str = os.getenv("TWILIO_FROM_NUMBER", "")

    # Print Service (e.g., Printful, Shiprocket)
    SHIPROCKET_EMAIL: str = os.getenv("SHIPROCKET_EMAIL", "")
    SHIPROCKET_PASSWORD: str = os.getenv("SHIPROCKET_PASSWORD", "")

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
