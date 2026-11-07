from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from bd import criar_db_tabelas
from routers import usuario

app = FastAPI()
app.mount("/static", StaticFiles(directory="static"), name="static")
app.include_router(usuario.router)

criar_db_tabelas()