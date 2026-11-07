

const log = document.getElementById("log");

async function getData(event) {
  event.preventDefault();

  let form = document.getElementById("form");
  let nome = document.getElementById('nome').value;
  let email = document.getElementById('email').value;

  log.textContent = `Formulario enviado`;
  
  try {
    const response = await fetch("/", {
        method: "POST",
        headers: {
          "Content-Type": "application/json" 
        },
        body: JSON.stringify({nome: nome, email: email})
    }

    );
    if (!response.ok) {
      throw new Error(`Response status: ${response.status}`);
    }

    const result = await response.json();
    console.log(result);
  } catch (error) {
    console.error(error.message);
  }
}

form.addEventListener("submit", getData);