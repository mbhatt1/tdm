from setuptools import setup, find_packages

setup(
    name="tvm",
    version="1.0.0",
    description="Trashfire Vending Machine - Stateless Cross-Platform Code Execution System",
    author="TVM Team",
    author_email="example@example.com",
    packages=find_packages(),
    install_requires=[
        "fastapi>=0.68.0",
        "uvicorn>=0.15.0",
        "httpx>=0.19.0",
        "pyyaml>=6.0",
        "pydantic>=1.8.2",
        "aiofiles>=0.7.0",
        "psutil>=5.8.0",
        "typer>=0.4.0",
        "rich>=10.12.0",
        "aiohttp>=3.8.1",
    ],
    extras_require={
        "dev": [
            "pytest>=6.2.5",
            "pytest-cov>=2.12.1",
            "flake8>=3.9.2",
            "black>=21.9b0",
            "isort>=5.9.3",
        ],
    },
    entry_points={
        "console_scripts": [
            "tvm=tvm.cli:app",
        ],
    },
    python_requires=">=3.8",
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
)