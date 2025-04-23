import sqlite3
import string
import random
from flask import Flask, request, redirect, render_template_string, g, url_for

app = Flask(__name__)
DATABASE = 'urls.db'

# HTML templates
INDEX_HTML = '''
<!doctype html>
<title>URL Shortener</title>
<h1>Shorten a URL</h1>
<form method=post>
  <input type=text name=url placeholder="Enter the URL to shorten" size=50 required>
  <input type=submit value=Shorten>
</form>
{% if short_url %}
<p>Short URL: <a href="{{ short_url }}">{{ short_url }}</a></p>
{% endif %}
<hr>
<h2>All URLs</h2>
<ul>
{% for orig, code, visits in entries %}
  <li><a href="{{ orig }}">{{ orig }}</a> &rarr; <a href="{{ request.host_url }}{{ code }}">{{ code }}</a> ({{ visits }} visits)</li>
{% endfor %}
</ul>
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
        code = generate_code()
        cursor = db.cursor()
        # ensure uniqueness
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

if __name__ == '__main__':
    init_db()
    app.run(host='0.0.0.0', port=5000, debug=True)
