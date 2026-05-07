import dotenv from "dotenv";
dotenv.config();

const [{ default: app }, { ensureDummyImages }, { ensureDemoPurchase }] = await Promise.all([
  import("./app.js"),
  import("./data/ensureDummyImages.js"),
  import("./data/ensureDemoPurchase.js"),
]);

try {
  ensureDummyImages();
  ensureDemoPurchase();
} catch (e) {
  console.error("[dummy] 시드 실행 실패:", e?.message || e);
}

const PORT = process.env.PORT || 4000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${PORT}`);
});