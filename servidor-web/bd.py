import os
from dotenv import load_dotenv
from sqlmodel import SQLModel, create_engine

load_dotenv()
engine = create_engine(os.environ["DATABASE_URL"])

def criar_db_tabelas():
    SQLModel.metadata.create_all(engine)


