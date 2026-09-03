abstract final class RemoteProfileFormHtml {
  static String page() {
    return '''
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1"/>
<title>Falcon IPTV</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body {
    margin: 0; font-family: system-ui, sans-serif;
    background: #0A0B10; color: #F4F7FF;
    padding: 20px 16px 40px;
  }
  h1 { font-size: 22px; margin: 0 0 6px; }
  p { color: #A8B0C4; margin: 0 0 18px; line-height: 1.4; }
  .tabs { display: flex; gap: 8px; margin-bottom: 16px; }
  button.tab, button.submit {
    border: 0; border-radius: 14px; padding: 12px 14px; font-weight: 800;
  }
  button.tab { flex: 1; background: #181B26; color: #F4F7FF; }
  button.tab.active { outline: 2px solid #00F0FF; color: #00F0FF; }
  label { display: block; font-size: 13px; color: #A8B0C4; margin: 12px 0 6px; }
  input {
    width: 100%; background: #181B26; color: #F4F7FF; border: 1px solid #33FFFFFF;
    border-radius: 12px; padding: 14px 12px; font-size: 16px;
  }
  button.submit {
    width: 100%; margin-top: 20px; background: #00F0FF; color: #0A0B10; font-size: 17px;
  }
  button.submit:disabled { opacity: .55; }
  .msg { margin-top: 14px; min-height: 1.4em; }
  .ok { color: #3DFF9A; }
  .err { color: #FF4D6D; }
  .hidden { display: none; }
</style>
</head>
<body>
  <h1>Falcon IPTV</h1>
  <p>Televizyona Xtream Codes veya M3U profili gönderiniz. Telefon ile TV aynı kablosuz ağda olmalıdır.</p>
  <div class="tabs">
    <button class="tab active" id="xtreamTab" type="button">Xtream Codes</button>
    <button class="tab" id="m3uTab" type="button">M3U</button>
  </div>
  <form id="form">
    <input type="hidden" name="type" id="type" value="xtream"/>
    <label>Profil adı</label>
    <input name="profileName" required placeholder="Ev" autocomplete="off"/>
    <div id="xtreamFields">
      <label>Sunucu URL</label>
      <input name="serverUrl" placeholder="http://sunucu:port" autocomplete="off"/>
      <label>Kullanıcı adı</label>
      <input name="username" autocomplete="username"/>
      <label>Şifre</label>
      <input name="password" type="password" autocomplete="current-password"/>
    </div>
    <div id="m3uFields" class="hidden">
      <label>M3U bağlantısı</label>
      <input name="m3uUrl" placeholder="http://.../playlist.m3u" autocomplete="off"/>
    </div>
    <button class="submit" id="send" type="submit">Televizyona gönder</button>
    <div class="msg" id="msg"></div>
  </form>
<script>
const params = new URLSearchParams(location.search);
const token = params.get("t") || "";
const form = document.getElementById("form");
const typeInput = document.getElementById("type");
const xtreamFields = document.getElementById("xtreamFields");
const m3uFields = document.getElementById("m3uFields");
const msg = document.getElementById("msg");
const send = document.getElementById("send");
function setType(type) {
  typeInput.value = type;
  document.getElementById("xtreamTab").classList.toggle("active", type === "xtream");
  document.getElementById("m3uTab").classList.toggle("active", type === "m3u");
  xtreamFields.classList.toggle("hidden", type !== "xtream");
  m3uFields.classList.toggle("hidden", type !== "m3u");
}
document.getElementById("xtreamTab").onclick = () => setType("xtream");
document.getElementById("m3uTab").onclick = () => setType("m3u");
form.onsubmit = async (event) => {
  event.preventDefault();
  msg.className = "msg";
  msg.textContent = "Gönderiliyor, lütfen bekleyiniz...";
  send.disabled = true;
  const data = Object.fromEntries(new FormData(form).entries());
  data.token = token;
  try {
    const response = await fetch("/api/add", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data),
    });
    const result = await response.json();
    if (result.ok) {
      msg.className = "msg ok";
      msg.textContent = "Profil televizyona kaydedildi. Kumanda ile profili seçebilirsiniz.";
    } else {
      throw new Error(result.error || "Kayıt tamamlanamadı.");
    }
  } catch (error) {
    msg.className = "msg err";
    msg.textContent = error.message || "Gönderilemedi. Aynı ağa bağlı olduğunuzdan emin olunuz.";
  }
  send.disabled = false;
};
</script>
</body>
</html>
''';
  }
}
