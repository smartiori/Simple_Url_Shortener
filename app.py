import sqlite3
import string
import random
from flask import Flask, request, redirect, render_template_string, g, url_for

app = Flask(__name__)
DATABASE = 'urls.db'

# HTML templates
INDEX_HTML = '''
<!doctype html>
<html>
<head>
    <title>URL Shortener</title>
    <style>
        body { font-family: Arial; max-width: 800px; margin: auto; padding: 2rem; }
        input[type=text] { padding: 0.5rem; width: 60%; }
        input[type=submit], button { padding: 0.5rem 1rem; margin-left: 0.5rem; }
        canvas { margin-top: 30px; }
    </style>
</head>
<body>
<h1>🔗 Shorten a URL</h1>
<form method=post>
  <input type=text name=url placeholder="Enter the URL to shorten" required>
  <input type=submit value=Shorten>
  <a href="{{ url_for('view_table') }}"><button type="button">📊 View Data Table</button></a>
</form>

{% if short_url %}
<p>✅ Short URL: <a href="{{ short_url }}">{{ short_url }}</a></p>
{% endif %}

<hr>
<h2>📈 Top URLs by Clicks</h2>
<canvas id="chart" width="600" height="300"></canvas>

<h2>🔍 All URLs</h2>
<ul>
{% for orig, code, visits in entries %}
  <li><a href="{{ orig }}">{{ orig }}</a> → 
      <a href="{{ request.host_url }}{{ code }}">{{ code }}</a> 
      ({{ visits }} visits)</li>
{% endfor %}
</ul>

<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script>
const ctx = document.getElementById('chart').getContext('2d');
const chart = new Chart(ctx, {
    type: 'bar',
    data: {
        labels: {{ labels|safe }},
        datasets: [{
            label: 'Visits',
            data: {{ data|safe }},
            backgroundColor: 'rgba(54, 162, 235, 0.6)'
        }]
    },
    options: {
        plugins: {
            legend: { display: false }
        },
        scales: {
            y: { beginAtZero: true }
        }
    }
});
</script>
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

    entries = db.execute('SELECT original_url, code, visits FROM urls ORDER BY id DESC').fetchall()
    top_entries = db.execute('SELECT code, visits FROM urls ORDER BY visits DESC LIMIT 5').fetchall()
    labels = [row['code'] for row in top_entries]
    data = [row['visits'] for row in top_entries]

    return render_template_string(INDEX_HTML, short_url=short_url, entries=entries,
                                  labels=labels, data=data)


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
