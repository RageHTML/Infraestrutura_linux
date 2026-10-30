
from fastapi import FastAPI, Request, Form,HTTPException
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from models import criar_db_tabelas
from pydantic import BaseModel
from typing import Annotated


app = FastAPI()
app.mount("/static", StaticFiles(directory="templates/static"), name="static")
templates = Jinja2Templates(directory="templates")
criar_db_tabelas()

class FormData(BaseModel):
    nome: str
    email: str


@app.get("/", response_class=HTMLResponse)
async def carregar_pagina_principal(request: Request):
    return templates.TemplateResponse(
        request=request, name="index.html"
    )

@app.post("/")
async def enviar(formulario: FormData):

    dados = formulario
    return {"mensagem": "Dados recebidos com sucesso!", "nome": dados.nome}
