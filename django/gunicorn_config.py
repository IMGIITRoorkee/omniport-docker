import os

bind = '0.0.0.0:8000'

reload = True

site_id = int(os.getenv('SITE_ID', '0'))
accesslog = f'/gunicorn_logs/{site_id}-access.log'
errorlog = f'/gunicorn_logs/{site_id}-error.log'