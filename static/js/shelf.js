(() => {
  const dialog = document.querySelector("#media-dialog");
  if (!dialog || typeof dialog.showModal !== "function") return;

  const title = dialog.querySelector("#media-dialog-title");
  const creator = dialog.querySelector("#media-dialog-creator");
  const format = dialog.querySelector("#media-dialog-format");
  const note = dialog.querySelector("#media-dialog-note");
  const cover = dialog.querySelector("#media-dialog-cover");
  const selection = dialog.querySelector("#media-dialog-selection");
  const selectionLabel = dialog.querySelector("#media-dialog-selection-label");
  const tracks = dialog.querySelector("#media-dialog-tracks");
  const link = dialog.querySelector("#media-dialog-link");

  document.querySelectorAll(".media-object").forEach((item) => {
    item.addEventListener("click", () => {
      title.textContent = item.dataset.title;
      creator.textContent = `${item.dataset.creator} · ${item.dataset.year}`;
      format.textContent = item.dataset.format;
      note.textContent = item.dataset.note;
      const itemCover = item.querySelector(".media-cover");
      dialog.classList.toggle("media-dialog--has-cover", Boolean(itemCover));
      dialog.classList.toggle("media-dialog--album", item.dataset.kind === "album");
      dialog.dataset.kind = item.dataset.kind;
      cover.hidden = !itemCover;
      if (itemCover) {
        cover.src = itemCover.currentSrc || itemCover.src;
        cover.alt = `Cover of ${item.dataset.title}`;
      } else {
        cover.removeAttribute("src");
        cover.alt = "";
      }
      const favoriteTracks = item.dataset.tracks
        ? item.dataset.tracks.split("|")
        : [];
      selection.hidden = item.dataset.favorite !== "album" && favoriteTracks.length === 0;
      tracks.hidden = favoriteTracks.length === 0;
      if (item.dataset.favorite === "album") {
        selectionLabel.textContent = "Loved front to back";
        tracks.textContent = "";
      } else if (favoriteTracks.length > 0) {
        selectionLabel.textContent = "Favorite tracks";
        tracks.textContent = favoriteTracks.join(" · ");
      } else {
        selectionLabel.textContent = "";
        tracks.textContent = "";
      }
      link.hidden = !item.dataset.link;
      if (item.dataset.link) {
        link.href = item.dataset.link;
        link.textContent = `${item.dataset.linkLabel || "More"} ↗`;
      } else {
        link.removeAttribute("href");
        link.textContent = "";
      }
      dialog.showModal();
    });
  });

  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) dialog.close();
  });
})();
