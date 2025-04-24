import sqlite3
import string
import random
from flask import Flask, request, redirect, render_template_string, g, url_for

app = Flask(__name__)
DATABASE = 'urls.db'

# HTML templates
INDEX_HTML = '''
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>FlaskShorty - URL Shortener</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
  </head>
  <body class="bg-light">
    <div class="container py-5">
      <div class="card shadow-sm">
        <div class="card-body">
          <h1 class="card-title">🔗 FlaskShorty</h1>
          <p class="card-text">Enter a URL below to shorten it:</p>
          <form method="post" class="row g-3">
            <div class="col-md-9">
              <input type="text" name="url" class="form-control" placeholder="Enter the URL to shorten" required>
            </div>
            <div class="col-md-3">
              <button type="submit" class="btn btn-primary w-100">Shorten</button>
            </div>
          </form>
          {% if short_url %}
          <div class="alert alert-success mt-4">
            Short URL: <a href="{{ short_url }}" target="_blank">{{ short_url }}</a>
          </div>
          {% endif %}
        </div>
      </div>

      <div class="mt-4 d-flex justify-content-between align-items-center">
        <h2>📜 All Shortened URLs</h2>
        <a href="{{ url_for('show_table') }}" target="_blank" class="btn btn-outline-secondary">View Table</a>
      </div>

      <ul class="list-group mt-2">
        {% for orig, code, visits in entries %}
        <li class="list-group-item d-flex justify-content-between align-items-center">
          <div>
            <a href="{{ orig }}" target="_blank">{{ orig }}</a>
            → <a href="{{ request.host_url }}{{ code }}" target="_blank">{{ code }}</a>
          </div>
          <span class="badge bg-info text-dark">{{ visits }} visits</span>
        </li>
        {% endfor %}
      </ul>
    </div>
  </body>
</html>
'''


# Database helper

def get_db():
    db = getattr(g, '_database', None)
    if db is None:
        db = g._database = sqlite3.connect(DATABASE)
        db.row_factory = sqlite3.Row
    return db

def init_db():
    with app.app_context():
        db = get_db()
        cursor = db.cursor()
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS urls (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                code TEXT UNIQUE,
                original_url TEXT,
                visits INTEGER DEFAULT 0
            )
        ''')
        db.commit()

def generate_code(length=6):
    chars = string.ascii_letters + string.digits
    return ''.join(random.choice(chars) for _ in range(length))

@app.teardown_appcontext
def close_connection(exception):
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()

@app.route('/', methods=['GET', 'POST'])
def index():
    db = get_db()
    short_url = None
    if request.method == 'POST':
        original = request.form['url']
        cursor = db.cursor()

        # Check if URL already exists
        row = cursor.execute('SELECT code FROM urls WHERE original_url = ?', (original,)).fetchone()
        if row:
            code = row['code']
        else:
            code = generate_code()
            while cursor.execute('SELECT * FROM urls WHERE code = ?', (code,)).fetchone():
                code = generate_code()
            cursor.execute('INSERT INTO urls (code, original_url) VALUES (?, ?)', (code, original))
            db.commit()
        short_url = url_for('redirect_short', code=code, _external=True)

    # fetch all entries
    entries = db.execute('SELECT original_url, code, visits FROM urls ORDER BY id DESC').fetchall()
    return render_template_string(INDEX_HTML, short_url=short_url, entries=entries)

@app.route('/<code>')
def redirect_short(code):
    db = get_db()
    cursor = db.cursor()
    row = cursor.execute('SELECT original_url, visits FROM urls WHERE code = ?', (code,)).fetchone()
    if row:
        # update visit count
        cursor.execute('UPDATE urls SET visits = visits + 1 WHERE code = ?', (code,))
        db.commit()
        return redirect(row['original_url'])
    return 'Invalid URL code', 404
@app.route('/table')
def show_table():
    db = get_db()
    rows = db.execute('SELECT * FROM urls ORDER BY id DESC').fetchall()
    table_html = '''
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <title>URL Table</title>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
      </head>
      <body class="p-4">
        <div class="container">
          <h2 class="mb-4">📊 URL Table</h2>
          <table class="table table-striped">
            <thead>
              <tr><th>ID</th><th>Code</th><th>Original URL</th><th>Visits</th></tr>
            </thead>
            <tbody>
    '''
    for row in rows:
        table_html += f"<tr><td>{row['id']}</td><td>{row['code']}</td><td>{row['original_url']}</td><td>{row['visits']}</td></tr>"
    table_html += '''
            </tbody>
          </table>
        </div>
      </body>
    </html>
    '''
    return table_html

if __name__ == '__main__':
    init_db()
    app.run(host='0.0.0.0', port=5000, debug=True)
