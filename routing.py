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
    file.save("./apps/audio/test.wav")
    
    query = "SELECT sex, model_location FROM users where username = %s"
    params = (username,)
    row = myDB.fetch(query, params)
    print(row[0])
    rc = call(["./verify.sh", username, row[0]])
    if rc == "true":
        response = {'username': username, 'statusCode': '200', 'statusMessage': 'Success'}
        return jsonify(response)
    else:
        response = {'username': username, 'statusCode': '100', 'statusMessage': 'Username and voice doesnt match'}
        return jsonify(response)
# POST
@app.route('/api/auth/register', methods=['POST'])
def register():
    """
    predicts requested text whether it is ham or spam
    :return: json
    """
    username = request.form['username']
    gender = request.form['gender'][0].lower()
    i = 0
    for file in request.files.getlist('voice'):
        file.save(f"./apps/audio/enroll{i}.wav")
        i += 1
    
    query = "SELECT id FROM users where username = %s"
    params = (username,)
    row = myDB.fetch(query, params)
    if row != None:
        response = {'username': username, 'statusCode': 200, 'statusMessage': 'Username is already taken'}
        return jsonify(response)
    id = "001"
    try:
        id = myDB.getLastId()+1
    except:
        print("First user")
    rc = call(["./enroll.sh", username, gender])
    query = "INSERT INTO users (username, sex) VALUES (%s, %s)"
    params = (username, gender)
    print(params)
    myDB.update(query, params)
    response = {'username': username, 'statusCode': '200', 'statusMessage': 'Success'}
    return jsonify(response)
    
# running web app in local machine
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
