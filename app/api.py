from flask import Flask, request  # redirect, url_for
from flask_restful import Resource, Api
from sqlalchemy import create_engine
from flask.ext.jsonpify import jsonify
from werkzeug.utils import secure_filename
import os


# CONFIG

UPLOAD_FOLDER = '../static/uploads'
ALLOWED_EXTENSIONS = set(['txt', 'pdf', 'png', 'jpg', 'jpeg', 'gif'])

db_connect = create_engine('sqlite:///chinook.db')
app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
api = Api(app)


# FUNCTIONS

def allowed_file(filename):
    """Check if uploaded file extension is allowed.

    Args:
        filename (str): Filename to check.

    Returns:
        bool: True if file extension is allowed, False otherwise.
        string: Extension of the checked file.
    """
    extension = filename.rsplit('.', 1)[1].lower()
    result = '.' in filename and \
        extension in ALLOWED_EXTENSIONS
    return result, extension


# API ENDPOINTS

class Employees(Resource):

    def get(self):
        conn = db_connect.connect()  # connect to database
        query = conn.execute("select * from employees")  # This line performs query and returns json result
        return {'employees': [i[0] for i in query.cursor.fetchall()]}  # Fetches first column that is Employee ID


class Tracks(Resource):

    def get(self):
        conn = db_connect.connect()
        query = conn.execute("select trackid, name, composer, unitprice from tracks;")
        result = {'data': [dict(zip(tuple(query.keys()), i)) for i in query.cursor]}
        return jsonify(result)


class Employees_Name(Resource):

    def get(self, employee_id):
        conn = db_connect.connect()
        query = conn.execute("select * from employees where EmployeeId =%d " % int(employee_id))
        result = {'data': [dict(zip(tuple(query.keys()), i)) for i in query.cursor]}
        return jsonify(result)


class Uploads(Resource):

    def post(self):
        file = request.files['file']
        if not file:
            error = {'error': 'No file present in the request'}
            return jsonify(error)

        filename = secure_filename(file.filename)
        allowed, extension = allowed_file(filename)
        if not allowed:
            error = {'error': 'The %s extension is not allowed, please upload an fbx, obj, or zip file' % extension}
            return jsonify(error)

        file.save(os.path.join(app.config['UPLOAD_FOLDER'], filename))
        result = {'result': 'Successfully uploaded %s' % filename}
        return jsonify(result)
        # return redirect(url_for('uploaded_file', filename=filename)) # In case we want to display a webpage


# ROUTES

api.add_resource(Employees, '/v1/employees')  # Route_1
api.add_resource(Tracks, '/v1/tracks')  # Route_2
api.add_resource(Employees_Name, '/v1/employees/<employee_id>')  # Route_3
api.add_resource(Uploads, '/v1/uploads')  # Route 4

if __name__ == '__main__':
     app.run(port='5010')