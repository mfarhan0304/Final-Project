from flask import Flask, request, json, jsonify
from db import MyDB
from subprocess import call

app = Flask(__name__)
myDB = MyDB()

# root
@app.route("/")
def index():
    """
    this is a root dir of my server
    :return: str
    """
    return "This is root!!!!"

# GET
@app.route('/api/auth/login', methods=['POST'])
def login():
    """
    Receive 5 audio files.
    Build a speaker model.
    """
    username = request.form['username']
    file = request.files['voice']
    file.save("tdsv/apps/data/{file.filename}")
    
    query = "SELECT id, gender FROM users where username = '{username}'"
    rc = call(['tdsv/verify.sh', id, gender])
    row = myDB.fetch(query)
    response = {'username': username, 'statusCode': '200', 'statusMessage': 'Success'}
    return jsonify(response)

# POST
@app.route('/api/auth/register', methods=['POST'])
def register():
    """
    predicts requested text whether it is ham or spam
    :return: json
    """
    username = request.form['username']
    gender = request.form['gender']
    for file in request.files.getlist('voice'):
        file.save(f"tdsv/apps/data/{file.filename}")
    
    query = "SELECT username FROM users where username = '{username}'"
    row = myDB.fetch(query)
    if row != None:
        response = {'username': username, statusCode': 200, 'statusMessage': 'Username is already taken'}
        return jsonify(response)
    
    id = myDB.getLastId()+1
    model_location = call("tdsv/enroll.sh", id, gender)

    query = "INSERT INTO users (username, model_location) VALUES ('{username}', '{model_location}')"
    myDB.update(query)
    response = {'username': username, 'statusCode': '200', 'statusMessage': 'Success'}
    return jsonify(response)
    
# running web app in local machine
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
