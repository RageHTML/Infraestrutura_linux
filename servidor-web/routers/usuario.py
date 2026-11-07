from fastapi import APIRouter, Request, HTTPException
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel

from models.usuario import salvar_no_banco, listar_usuarios

router = APIRouter()
templates = Jinja2Templates(directory="templates")


class FormData(BaseModel):
    nome: str
    email: str


@router.get("/", response_class=HTMLResponse)
async def carregar_pagina_principal(request: Request):
    return templates.TemplateResponse(request=request, name="usuario.html")


@router.post("/")
def enviar(formulario: FormData):
    try:
        usuario = salvar_no_banco(formulario.nome, formulario.email)
    except Exception:
        raise HTTPException(status_code=500, detail="Erro ao salvar no banco")
    return {"mensagem": "Dados salvos com sucesso!", "id": usuario.id, "nome": usuario.nome}


@router.get("/usuarios")
def usuarios():
    return listar_usuarios()