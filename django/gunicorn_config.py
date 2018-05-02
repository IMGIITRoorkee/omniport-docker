import os

bind = '0.0.0.0:8000'

reload = True

site_name = os.getenv('SITE_NAME')
accesslog = f'/gunicorn_logs/{site_name}-access.log'
errorlog = f'/gunicorn_logs/{site_name}-error.log'