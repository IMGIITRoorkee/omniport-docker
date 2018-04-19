import os

port = os.getenv('GUNICORN_PORT')
bind = f'0.0.0.0:{port}'

reload = True

site_name = os.getenv('SITE_NAME')
accesslog = f'/gunicorn_logs/{site_name}-access.log'
errorlog = f'/gunicorn_logs/{site_name}-error.log'