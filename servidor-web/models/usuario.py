from sqlmodel import Field, Session, SQLModel, select
from bd import engine

class Usuario(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    nome: str
    email: str

def salvar_no_banco(nome: str, email: str) -> Usuario:
    with Session(engine) as session:
        usuario = Usuario(nome=nome, email=email)
        session.add(usuario)
        session.commit()
        session.refresh(usuario)
        return usuario

def listar_usuarios() -> list[Usuario]:
    with Session(engine) as session:
        return list(session.exec(select(Usuario)).all())