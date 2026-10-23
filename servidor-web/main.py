from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlmodel import SQLModel, create_engine

app = FastAPI()

templates = Jinja2Templates(directory="templates")
url = f"postgresql+psycopg://admin:asd1234@10.0.3.10:5432/recadastro"


engine = create_engine(url, echo=True)
SQLModel.metadata.create_all(engine)

@app.get("/", response_class=HTMLResponse)
async def read_item(request: Request):
    return templates.TemplateResponse(
        request=request, name="index.html"
    )

@app.get("/")
async def root():
    return {"message": "Hello World"}