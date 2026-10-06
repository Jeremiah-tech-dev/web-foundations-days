const USERS_URL = "https://jsonplaceholder.typicode.com/users";

const loadButton = document.querySelector("#load-users");
const filterInput = document.querySelector("#filter-input");
const statusText = document.querySelector("#status");
const usersList = document.querySelector("#users-list");

let allUsers = [];

function renderUsers(list) {
  usersList.innerHTML = "";

  list.forEach((user) => {
    const li = document.createElement("li");

    const name = document.createElement("strong");
    name.textContent = user.name;

    const details = document.createElement("p");
    details.textContent =
      `${user.email} · ${user.address.city} · ${user.company.name}`;

    li.appendChild(name);
    li.appendChild(details);
    usersList.appendChild(li);
  });
}

function applyFilter() {
  if (allUsers.length === 0) return; // nothing loaded yet

  const search = filterInput.value.trim().toLowerCase();
  const matches = allUsers.filter((user) =>
    user.name.toLowerCase().includes(search)
  );

  renderUsers(matches);

  if (matches.length === 0) {
    statusText.textContent = "No users match your filter.";
  } else if (search === "") {
    statusText.textContent = `Loaded ${allUsers.length} users.`;
  } else {
    statusText.textContent =
      `Showing ${matches.length} of ${allUsers.length} users.`;
  }
}

async function loadUsers() {
  statusText.textContent = "Loading users...";
  loadButton.disabled = true;
  usersList.innerHTML = "";

  try {
    const response = await fetch(USERS_URL);
    if (!response.ok) throw new Error(`Status ${response.status}`);
    allUsers = await response.json();
    applyFilter();
  } catch (error) {
    allUsers = [];
    statusText.textContent = "Could not load users. Please try again.";
    console.error(error);
  } finally {
    loadButton.disabled = false; // runs whether it worked or failed
  }
}

loadButton.addEventListener("click", loadUsers);
filterInput.addEventListener("input", applyFilter);
