# Simple URL Shortener

A lightweight, self-hosted URL shortening service built with Flask and SQLite. Generate your own short links, track click statistics, and deploy easily on any VPS.

## Features

- **Shorten URLs**: Generate 6-character unique codes for any long URL.
- **Redirect**: Click on a short link to seamlessly redirect to the original URL.
- **Visit Tracking**: Count and display total visits for each shortened link.
- **Management UI**: Web interface to view, create, and manage all short links.

## Prerequisites

- Python 3.7 or higher
- Pip

## Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/smartiori/Simple_Url_Shortener.git
   ```
2. **Create a virtual environment** (optional but recommended)
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```
3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

## Usage

1. **Initialize the database** (creates `urls.db`)
   ```bash
   python app.py init-db
   ```
2. **Run the application**
   ```bash
   python app.py
   ```
3. **Access the UI** Open `http://<YOUR_SERVER_IP>:5000/` in your browser.

## Deployment

For production deployments, consider using Gunicorn behind Nginx:

```bash
# Run with Gunicorn
gunicorn app:app -b 0.0.0.0:8000 --workers 4
```

Configure Nginx as a reverse proxy to forward requests on port 80 to Gunicorn on port 8000.

Alternatively, you can use Docker Compose. A sample `docker-compose.yml` is provided in the repository.

## Configuration

- **DATABASE**: Path to SQLite database file (default: `urls.db`)
- **APP\_HOST**: Host to bind (default: `0.0.0.0`)
- **APP\_PORT**: Port to listen on (default: `5000`)

You can override these via environment variables.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature-name`)
3. Commit your changes (`git commit -m "Add feature"`)
4. Push to the branch (`git push origin feature-name`)
5. Open a Pull Request

Please ensure any new feature includes tests and documentation.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

