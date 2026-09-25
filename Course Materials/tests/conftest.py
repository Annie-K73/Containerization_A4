import pytest

from app import create_app
from app.config import Settings


@pytest.fixture
def settings() -> Settings:
    return Settings(
        application_name="delivery-api",
        app_version="1.2.3",
        git_sha="abc123def456",
        environment="test",
        log_level="WARNING",
        database_host="postgres",
        database_port=5432,
        postgres_db="delivery",
        postgres_user="delivery",
        postgres_password="unit-test-only",
    )


@pytest.fixture
def app(settings):
    application = create_app(settings)
    application.config.update(TESTING=True)
    return application


@pytest.fixture
def client(app):
    return app.test_client()
