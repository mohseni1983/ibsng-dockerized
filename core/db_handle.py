from core.db_conf import *
def getDBHandle():
    from core.db import db_pg
    # Use DB_NAME if available, otherwise default to "IBSng" for backward compatibility
    db_name = globals().get('DB_NAME', 'IBSng')
    return db_pg.db_pg(db_name,DB_HOST,DB_PORT,DB_USERNAME,DB_PASSWORD)
