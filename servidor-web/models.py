from typing import Annotated
from fastapi import Depends, FastAPI, HTTPException, Query
from sqlmodel import Field, SQLModel, create_engine

url = f"postgresql+psycopg://admin:asd1234@10.0.3.10:5432/recadastro"
engine = create_engine(url, echo=True)

class Usuario(SQLModel, table=True):
    id: int = Field(primary_key=True)
    nome: str = Field()
    email: int = Field()

def criar_db_tabelas():
    SQLModel.metadata.create_all(engine)

def salvar_no_banco():
    return None 
