from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, Query
from sqlmodel import Field, Session, SQLModel, create_engine, select


class Usuario(SQLModel, table=True):
    id: int = Field(primary_key=True)
    nome: str = Field()
    email: int = Field()

# Code below omitted 👇