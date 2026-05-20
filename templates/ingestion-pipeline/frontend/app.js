const API_BASE = "";

document.getElementById("upload-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const password = document.getElementById("password").value;
  const file = document.getElementById("file-input").files[0];
  if (!file) return;

  const el = (id) => document.getElementById(id);
  el("status").classList.add("hidden");

  try {
    const urlResp = await fetch(`${API_BASE}/get-upload-url`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${password}`,
      },
      body: JSON.stringify({ filename: file.name }),
    });
    if (!urlResp.ok)
      return showStatus((await urlResp.json()).error || "Failed", "error");
    const { upload_url, object_key } = await urlResp.json();

    el("progress-container").classList.remove("hidden");
    const xhr = new XMLHttpRequest();
    xhr.open("PUT", upload_url, true);
    xhr.setRequestHeader("Content-Type", "application/octet-stream");
    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable) {
        const pct = Math.round((e.loaded / e.total) * 100);
        el("progress-fill").style.width = `${pct}%`;
        el("progress-text").textContent = `${pct}%`;
      }
    };
    xhr.onload = async () => {
      if (xhr.status !== 200)
        return showStatus(`Upload failed: ${xhr.status}`, "error");
      const confirmResp = await fetch(`${API_BASE}/confirm-upload`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${password}`,
        },
        body: JSON.stringify({ object_key }),
      });
      showStatus(
        confirmResp.ok
          ? "Complete! Processing queued."
          : "Upload OK but confirmation failed.",
        confirmResp.ok ? "success" : "error",
      );
    };
    xhr.onerror = () => showStatus("Upload failed: network error", "error");
    xhr.send(file);
  } catch (err) {
    showStatus(`Error: ${err.message}`, "error");
  }
});

function showStatus(msg, type) {
  const s = document.getElementById("status");
  s.textContent = msg;
  s.className = type;
  s.classList.remove("hidden");
}
