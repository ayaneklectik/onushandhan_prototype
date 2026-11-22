(() => {
  const state = {
    user: null,
    csrfToken: "",
    view: "dashboard",
    articleOffset: 0,
    articleFilters: {},
    categories: [],
    articles: [],
    toastTimer: null,
  };
  const roles = {
    super_admin: "Super Admin",
    admin: "Admin",
    moderator: "Moderator",
  };
  const statuses = {
    published: "Published",
    draft: "Draft",
    unpublished: "Unpublished",
    active: "Active",
    suspended: "Suspended",
  };
  const categoryLayouts = {
    "lead-headlines": "Featured story + headlines",
    "feature-headlines": "Large image + headlines only",
    "image-grid": "Image card grid",
    "headline-list": "Headlines only",
  };
  const navigation = [
    { id: "dashboard", label: "Dashboard", symbol: "⌂", roles: ["super_admin", "admin", "moderator"] },
    { id: "articles", label: "Manage all news", symbol: "▤", roles: ["super_admin", "admin", "moderator"] },
    { id: "videos", label: "Videos", symbol: "▷", roles: ["super_admin", "admin", "moderator"] },
    { id: "categories", label: "Categories", symbol: "▦", roles: ["super_admin"] },
    { id: "sections", label: "Homepage sections", symbol: "▣", roles: ["super_admin"] },
    { id: "settings", label: "Site settings", symbol: "⚙", roles: ["super_admin"] },
    { id: "users", label: "Users", symbol: "♙", roles: ["super_admin", "admin"] },
  ];

  const loginPanel = document.querySelector("#login-panel");
  const adminApp = document.querySelector("#admin-app");
  const loginForm = document.querySelector("#login-form");
  const loginError = document.querySelector("#login-error");
  const pageContent = document.querySelector("#page-content");
  const nav = document.querySelector("#admin-nav");
  const modal = document.querySelector("#modal");
  const modalTitle = document.querySelector("#modal-title");
  const modalContent = document.querySelector("#modal-content");
  const toast = document.querySelector("#toast");

  function escapeHtml(value = "") {
    return String(value).replace(/[&<>"']/g, (character) => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;",
    })[character]);
  }
  function date(value) {
    if (!value) return "—";
    return new Intl.DateTimeFormat("en", {
      dateStyle: "medium",
      timeStyle: "short",
    }).format(new Date(value));
  }
  function statusPill(status) {
    return `<span class="status-pill status-${escapeHtml(status)}">${escapeHtml(statuses[status] || status)}</span>`;
  }

  async function showUserActivity(userId) {
    const data = await request(`/api/admin/users/${userId}/activity`);
    const rows = data.activity.map((item) => `
      <div class="activity-row"><div>${escapeHtml(item.action)} ${escapeHtml(item.entity_type)}
        <small>${date(item.created_at)}</small></div></div>
    `).join("");
    openModal("User activity", rows || emptyPanel("No activity recorded for this account."));
  }

  function showToast(message, isError = false) {
    clearTimeout(state.toastTimer);
    toast.textContent = message;
    toast.classList.toggle("is-error", isError);
    toast.classList.add("is-visible");
    state.toastTimer = setTimeout(() => toast.classList.remove("is-visible"), 3600);
  }

  async function request(url, options = {}) {
    const method = (options.method || "GET").toUpperCase();
    let response;
    let data;
    for (let attempt = 0; attempt < 2; attempt += 1) {
      const headers = new Headers(options.headers || {});
      if (options.body && !(options.body instanceof FormData)) {
        headers.set("Content-Type", "application/json");
      }
      if (!["GET", "HEAD", "OPTIONS"].includes(method)) {
        headers.set("X-CSRF-Token", state.csrfToken);
      }
      response = await fetch(url, {
        ...options,
        method,
        headers,
        credentials: "same-origin",
      });
      data = response.status === 204 ? {} : await response.json().catch(() => ({}));
      if (response.status !== 403 || data.error !== "Invalid CSRF token." || attempt > 0) break;
      await loadCsrf();
    }
    if (!response.ok) {
      if (response.status === 401 && adminApp && !adminApp.hidden) {
        await showLogin();
      }
      throw new Error(data.error || `Request failed (${response.status}).`);
    }
    if (data.csrfToken) state.csrfToken = data.csrfToken;
    return data;
  }

  async function loadCsrf() {
    const response = await fetch("/api/csrf", { credentials: "same-origin" });
    const data = await response.json();
    if (!response.ok || !data.csrfToken) throw new Error(data.error || "Could not initialize a secure session.");
    state.csrfToken = data.csrfToken;
  }

  function showLogin() {
    state.user = null;
    adminApp.hidden = true;
    document.querySelector("#account-bar").hidden = true;
    loginPanel.hidden = false;
  }

  function showAdmin(user) {
    state.user = user;
    loginPanel.hidden = true;
    adminApp.hidden = false;
    document.querySelector("#account-bar").hidden = false;
    document.querySelector("#account-name").textContent = `${user.username} · ${roles[user.role]}`;
    renderNavigation();
    return navigate(state.view);
  }

  function renderNavigation() {
    nav.innerHTML = navigation
      .filter((item) => item.roles.includes(state.user.role))
      .map((item) => `
        <a href="#${item.id}" data-view="${item.id}" ${state.view === item.id ? 'aria-current="page"' : ""}>
          <span class="nav-symbol" aria-hidden="true">${item.symbol}</span>
          <span>${item.label}</span>
        </a>
      `)
      .join("");
  }

  function setHeading(title, description = "", action = "") {
    return `
      <header class="page-heading">
        <div><h1>${title}</h1>${description ? `<p>${description}</p>` : ""}</div>
        ${action}
      </header>
    `;
  }

  function emptyPanel(message) {
    return `<div class="empty-inline">${message}</div>`;
  }

  function openModal(title, html) {
    modalTitle.textContent = title;
    modalContent.innerHTML = html;
    modal.showModal();
  }

  function closeModal() {
    modal.close();
    modalContent.replaceChildren();
  }

  async function navigate(view) {
    const item = navigation.find((entry) => entry.id === view);
    if (!item || !item.roles.includes(state.user.role)) return;
    state.view = view;
    renderNavigation();
    pageContent.innerHTML = `<div class="empty-panel">${emptyPanel("Loading…")}</div>`;
    try {
      if (view === "dashboard") await renderDashboard();
      if (view === "articles") await renderArticles();
      if (view === "videos") await renderVideos();
      if (view === "categories") await renderCategories();
      if (view === "sections") await renderSections();
      if (view === "settings") await renderSettings();
      if (view === "users") await renderUsers();
    } catch (error) {
      pageContent.innerHTML = `<div class="empty-panel">${emptyPanel(escapeHtml(error.message))}</div>`;
      showToast(error.message, true);
    }
  }

  async function renderDashboard() {
    const data = await request("/api/admin/dashboard");
    const stats = [
      ["Published articles", data.stats.published],
      ["Drafts", data.stats.drafts],
      ["Unpublished articles", data.stats.unpublished],
      ["Categories", `${data.stats.categories} / ${data.stats.subcategories} subcategories`],
      ["Videos", data.stats.videos],
      ...(data.stats.users === null ? [] : [["Registered users", data.stats.users]]),
    ];
    const cards = stats.map(([label, value]) => `
      <article class="stat-card"><span>${label}</span><strong>${value ?? "—"}</strong></article>
    `).join("");
    const activity = data.activity.length
      ? data.activity.map((item) => `
          <div class="activity-row">
            <div><strong>${escapeHtml(item.username || "System")}</strong> · ${escapeHtml(item.action)} ${escapeHtml(item.entity_type)}
              <small>${date(item.created_at)}</small>
            </div>
          </div>
        `).join("")
      : emptyPanel("No activity recorded yet.");
    const recent = data.recentlyUpdated.length
      ? data.recentlyUpdated.map((item) => `
          <div class="recent-row"><div>${escapeHtml(item.title)}<small>${date(item.updated_at)}</small></div>${statusPill(item.status)}</div>
        `).join("")
      : emptyPanel("No articles have been created yet.");
    const published = data.recentlyPublished.length
      ? data.recentlyPublished.map((item) => `
          <div class="recent-row"><div>${escapeHtml(item.title)}<small>${date(item.published_at)}</small></div><span class="status-pill status-published">Published</span></div>
        `).join("")
      : emptyPanel("No published articles yet.");
    pageContent.innerHTML = `
      ${setHeading("Dashboard", "A live overview of newsroom content and activity.")}
      <div class="stats-grid">${cards}</div>
      <div class="dashboard-grid">
        <section class="panel"><div class="panel-heading"><h2>Recently updated</h2></div><div class="panel-body">${recent}</div></section>
        <section class="panel"><div class="panel-heading"><h2>Recently published</h2></div><div class="panel-body">${published}</div></section>
        <section class="panel"><div class="panel-heading"><h2>Activity</h2></div><div class="panel-body">${activity}</div></section>
      </div>
    `;
  }

  async function getEditorCategories() {
    const data = await request("/api/editor/categories");
    state.categories = data.categories;
    return state.categories;
  }

  async function renderArticles() {
    const [categories] = await Promise.all([getEditorCategories()]);
    const params = new URLSearchParams({
      limit: "50",
      offset: String(state.articleOffset),
      ...state.articleFilters,
    });
    const data = await request(`/api/admin/articles?${params}`);
    state.articles = data.articles;
    const categoryOptions = categories.map((item) => `
      <option value="${item.id}" ${state.articleFilters.categoryId === item.id ? "selected" : ""}>${escapeHtml(item.parent_name ? `${item.parent_name} / ${item.name}` : item.name)}</option>
    `).join("");
    const rows = data.articles.map((article) => {
      const actions = [
        `<button class="button button-secondary" data-action="preview-article" data-id="${article.id}">Preview</button>`,
      ];
      if (state.user.role !== "moderator" || article.status === "draft") {
        actions.unshift(`<button class="button button-secondary" data-action="edit-article" data-id="${article.id}">Edit</button>`);
      }
      if (state.user.role !== "moderator") {
        actions.push(
          `<button class="button button-secondary" data-action="article-status" data-status="${article.status === "published" ? "unpublished" : "published"}" data-id="${article.id}">${article.status === "published" ? "Unpublish" : "Publish"}</button>`,
          `<button class="button button-danger" data-action="delete-article" data-id="${article.id}">Delete</button>`,
        );
      }
      return `
        <tr>
          <td><div class="story-cell">${article.image_url ? `<img class="table-thumb" src="${escapeHtml(article.image_url)}" alt="">` : '<span class="table-thumb"></span>'}
            <div><strong>${escapeHtml(article.title)}</strong><small>${escapeHtml(article.slug)}</small></div>
          </div></td>
          <td>${escapeHtml(article.category || "—")}</td>
          <td>${escapeHtml(article.author)}</td>
          <td>${date(article.published_at || article.updated_at)}</td>
          <td>${escapeHtml(article.sections || "—")}</td>
          <td>${statusPill(article.status)}</td>
          <td><div class="row-actions">${actions.join("")}</div></td>
        </tr>
      `;
    }).join("");
    pageContent.innerHTML = `
      ${setHeading("Manage all news", `${data.total} article${data.total === 1 ? "" : "s"} in this view.`,
        '<button class="button button-primary" data-action="new-article">＋ New article</button>')}
      <form id="article-filters" class="filters">
        <input name="q" aria-label="Search articles" placeholder="Search title or headline" value="${escapeHtml(state.articleFilters.q || "")}">
        <select name="status" aria-label="Filter by status">
          <option value="">All statuses</option>
          ${["published", "draft", "unpublished"].map((status) => `<option value="${status}" ${state.articleFilters.status === status ? "selected" : ""}>${statuses[status]}</option>`).join("")}
        </select>
        <select name="categoryId" aria-label="Filter by category">
          <option value="">All categories</option>${categoryOptions}
        </select>
        <button class="button button-secondary" type="submit">Apply filters</button>
        <button class="button button-secondary" type="button" data-action="reset-article-filters">Reset</button>
      </form>
      <div class="table-panel"><div class="table-scroll"><table>
        <thead><tr><th>Article</th><th>Category</th><th>Author</th><th>Published / updated</th><th>Appears in</th><th>Status</th><th>Actions</th></tr></thead>
        <tbody>${rows || `<tr><td colspan="7">${emptyPanel("No articles match this view.")}</td></tr>`}</tbody>
      </table></div></div>
      <div class="form-actions">
        <button class="button button-secondary" data-action="articles-prev" ${state.articleOffset <= 0 ? "disabled" : ""}>Previous</button>
        <button class="button button-secondary" data-action="articles-next" ${state.articleOffset + 50 >= data.total ? "disabled" : ""}>Next</button>
      </div>
    `;
  }

  function categorySelectOptions(selected = "") {
    const selectedCategory = state.categories.find((category) => category.id === selected);
    const legacyVideoCategory = selectedCategory?.slug === "video-podcast"
      ? `<option value="${selectedCategory.id}" selected>${escapeHtml(selectedCategory.name)} (existing article; videos only)</option>`
      : "";
    return legacyVideoCategory + state.categories
      .filter((category) => category.slug !== "video-podcast")
      .map((category) => `
      <option value="${category.id}" ${selected === category.id ? "selected" : ""}>${escapeHtml(category.name)}</option>
    `).join("");
  }

  async function uploadFile(file, mediaType, statusElement) {
    if (!file) return null;
    statusElement.textContent = "Preparing upload…";
    const upload = await request("/api/admin/media/uploads", {
      method: "POST",
      body: JSON.stringify({ mediaType, contentType: file.type, sizeBytes: file.size }),
    });
    const response = await fetch(upload.uploadUrl, {
      method: upload.uploadMethod || "PUT",
      headers: { "Content-Type": upload.contentType || file.type },
      body: file,
    });
    if (!response.ok) throw new Error(`Upload failed (${response.status}). Check the media bucket CORS configuration.`);
    statusElement.textContent = "Verifying upload…";
    const completed = await request(`/api/admin/media/uploads/${upload.assetId}/complete`, { method: "POST" });
    statusElement.textContent = "Upload complete.";
    return completed;
  }

  async function openArticleEditor(articleId = "") {
    await getEditorCategories();
    const article = articleId ? (await request(`/api/admin/articles/${articleId}`)).article : null;
    openModal(article ? "Edit article" : "Create article", `
      <form id="article-editor" class="stack-form" data-id="${article?.id || ""}">
        <div class="form-grid">
          <label class="full-width">Title <input name="title" maxlength="240" required value="${escapeHtml(article?.title || "")}"></label>
          <label class="full-width">Headline <input name="headline" maxlength="300" value="${escapeHtml(article?.headline || "")}"></label>
          <label class="full-width">Summary <textarea name="summary" maxlength="1000" rows="3">${escapeHtml(article?.summary || "")}</textarea></label>
          <label>Category
            <select name="categoryId"><option value="">No category</option>${categorySelectOptions(article?.category_id || "")}</select>
          </label>
          <label>URL slug <input name="slug" value="${escapeHtml(article?.slug || "")}" placeholder="Generated from title for new articles" ${article ? "" : "disabled"}></label>
          <label class="full-width">Article image
            <span class="image-upload">
              <img class="image-preview" id="article-image-preview" src="${escapeHtml(article?.image_url || "")}" alt="">
              <span><input id="article-image-file" type="file" accept="image/jpeg,image/png,image/webp,image/avif">
                <small class="form-help">JPG, PNG, WebP or AVIF. Maximum 10 MB.</small>
              </span>
              <button type="button" class="button button-secondary button-small" data-action="clear-article-image">Remove image</button>
            </span>
            <span id="article-upload-status" class="form-help"></span>
          </label>
          <label>Image description <input name="imageAlt" maxlength="300" value="${escapeHtml(article?.image_alt || "")}"></label>
          <label class="full-width">Photo caption / ছবির ক্যাপশন <input name="imageCaption" maxlength="500" value="${escapeHtml(article?.image_caption || "")}"></label>
          <label>Photo credit / ছবির সূত্র <input name="imageCredit" maxlength="300" value="${escapeHtml(article?.image_credit || "")}" placeholder="ছবি: নিজস্ব প্রতিবেদক"></label>
          <label>Attribution / প্রতিবেদনের সূত্র <input name="attribution" maxlength="300" value="${escapeHtml(article?.attribution || "")}" placeholder="২৪ঘণ্টা অনলাইন"></label>
          <input type="hidden" name="imageKey" value="${escapeHtml(article?.image_key || "")}">
          <label class="full-width">Article body / প্রতিবেদনের মূল লেখা
            <div class="editor-toolbar" role="toolbar" aria-label="Text formatting">
              <button type="button" data-format="bold"><strong>B</strong></button>
              <button type="button" data-format="italic"><em>I</em></button>
              <button type="button" data-format="underline"><u>U</u></button>
              <button type="button" data-format="h2">শিরোনাম</button>
              <button type="button" data-format="p">অনুচ্ছেদ</button>
              <button type="button" data-format="blockquote">উদ্ধৃতি</button>
              <button type="button" data-format="ul">• তালিকা</button>
              <button type="button" data-format="ol">১. তালিকা</button>
              <button type="button" data-format="link">লিংক</button>
              <button type="button" data-format="remove">ফরম্যাট মুছুন</button>
            </div>
            <div id="article-body-editor" class="article-rich-editor" contenteditable="true" role="textbox" aria-multiline="true" data-placeholder="এখানে প্রতিবেদন লিখুন…">${article?.body || ""}</div>
            <textarea name="body" hidden maxlength="100000">${escapeHtml(article?.body || "")}</textarea>
          </label>
        </div>
        <div class="form-actions">
          <button type="button" class="button button-secondary" data-action="close-modal">Cancel</button>
          <button type="submit" class="button button-secondary" data-submit-action="save">Save draft</button>
          ${state.user.role === "moderator" ? "" : '<button type="submit" class="button button-primary" data-submit-action="publish">Save & publish</button>'}
        </div>
      </form>
    `);
    const form = document.querySelector("#article-editor");
    const richEditor = form.querySelector("#article-body-editor");
    const bodyField = form.elements.body;
    form.querySelectorAll("[data-format]").forEach((button) => {
      button.addEventListener("mousedown", (event) => event.preventDefault());
      button.addEventListener("click", () => {
        richEditor.focus();
        const format = button.dataset.format;
        if (format === "link") {
          const url = window.prompt("HTTPS link URL:");
          if (!url || !/^https:\/\//i.test(url)) return;
          document.execCommand("createLink", false, url);
        } else if (format === "remove") {
          document.execCommand("removeFormat");
        } else if (format === "h2") {
          document.execCommand("formatBlock", false, "h2");
        } else if (format === "p") {
          document.execCommand("formatBlock", false, "p");
        } else if (format === "blockquote") {
          document.execCommand("formatBlock", false, "blockquote");
        } else if (format === "ul") {
          document.execCommand("insertUnorderedList");
        } else if (format === "ol") {
          document.execCommand("insertOrderedList");
        } else {
          document.execCommand(format);
        }
      });
    });
    const file = document.querySelector("#article-image-file");
    file.addEventListener("change", async () => {
      const status = document.querySelector("#article-upload-status");
      try {
        const uploaded = await uploadFile(file.files[0], "image", status);
        if (!uploaded) return;
        form.elements.imageKey.value = uploaded.objectKey;
        document.querySelector("#article-image-preview").src = uploaded.url;
      } catch (error) {
        status.textContent = error.message;
        showToast(error.message, true);
      }
    });
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      const submitAction = event.submitter?.dataset.submitAction || "save";
      bodyField.value = richEditor.innerHTML;
      const formData = new FormData(form);
      const data = {
        title: formData.get("title"),
        headline: formData.get("headline"),
        summary: formData.get("summary"),
        body: form.querySelector("#article-body-editor").innerHTML,
        attribution: formData.get("attribution"),
        imageCaption: formData.get("imageCaption"),
        imageCredit: formData.get("imageCredit"),
        categoryId: formData.get("categoryId") || null,
        imageKey: formData.get("imageKey") || null,
        imageAlt: formData.get("imageAlt"),
      };
      const slug = formData.get("slug");
      if (slug) data.slug = slug;
      const saveButton = event.submitter;
      saveButton.disabled = true;
      try {
        const saved = await request(
          article ? `/api/admin/articles/${article.id}` : "/api/admin/articles",
          { method: article ? "PATCH" : "POST", body: JSON.stringify(data) },
        );
        const id = article?.id || saved.article.id;
        if (submitAction === "publish") {
          await request(`/api/admin/articles/${id}/status`, {
            method: "PATCH",
            body: JSON.stringify({ status: "published" }),
          });
        }
        closeModal();
        showToast(submitAction === "publish" ? "Article published." : "Draft saved.");
        await renderArticles();
      } catch (error) {
        showToast(error.message, true);
        saveButton.disabled = false;
      }
    });
  }

  function previewArticle(article) {
    openModal("Article preview", `
      <article>
        ${article.image_url ? `<img class="preview-image" src="${escapeHtml(article.image_url)}" alt="${escapeHtml(article.image_alt || "")}">` : ""}
        <p class="eyebrow">${escapeHtml(article.category || "Uncategorized")}</p>
        <h1>${escapeHtml(article.headline || article.title)}</h1>
        ${article.summary ? `<p>${escapeHtml(article.summary)}</p>` : ""}
        <div class="preview-copy">${escapeHtml(article.body || "")}</div>
      </article>
    `);
  }

  async function renderVideos() {
    const { videos } = await request("/api/admin/videos");
    const rows = videos.map((video) => {
      const actions = [
        `<button class="button button-secondary" data-action="edit-video" data-id="${video.id}">Edit</button>`,
      ];
      if (state.user.role !== "moderator") {
        actions.push(
          `<button class="button button-secondary" data-action="video-status" data-status="${video.status === "published" ? "unpublished" : "published"}" data-id="${video.id}">${video.status === "published" ? "Unpublish" : "Publish"}</button>`,
          `<button class="button button-danger" data-action="delete-video" data-id="${video.id}">Delete</button>`,
        );
      } else if (video.status !== "draft") {
        actions.pop();
      }
      return `<tr>
        <td><div class="story-cell">${video.thumbnail_url ? `<img class="table-thumb" src="${escapeHtml(video.thumbnail_url)}" alt="">` : '<span class="table-thumb"></span>'}
          <div><strong>${escapeHtml(video.title)}</strong><small>${video.source_type === "external" ? "YouTube video" : "Previously uploaded video"}</small></div>
        </div></td>
        <td>${escapeHtml(video.author)}</td><td>${date(video.published_at || video.updated_at)}</td>
        <td>${statusPill(video.status)}</td><td><div class="row-actions">${actions.join("")}</div></td></tr>`;
    }).join("");
    pageContent.innerHTML = `
      ${setHeading("Video management", "Add a YouTube video with its headline and description. The thumbnail is loaded automatically.",
        '<button class="button button-primary" data-action="new-video">＋ Add video</button>')}
      <div class="table-panel"><div class="table-scroll"><table><thead><tr><th>Video</th><th>Author</th><th>Published / updated</th><th>Status</th><th>Actions</th></tr></thead>
        <tbody>${rows || `<tr><td colspan="5">${emptyPanel("No videos added yet.")}</td></tr>`}</tbody></table></div></div>
    `;
  }

  async function openVideoEditor(videoId = "") {
    const video = videoId ? (await request("/api/admin/videos")).videos.find((item) => item.id === videoId) : null;
    openModal(video ? "Edit video" : "Add video", `
      <form id="video-editor" class="stack-form" data-id="${video?.id || ""}">
        <label>Headline <input name="title" maxlength="240" required value="${escapeHtml(video?.title || "")}"></label>
        <label>Description <textarea name="description" maxlength="2000" rows="4">${escapeHtml(video?.description || "")}</textarea></label>
        <label ${video?.source_type === "upload" ? "hidden" : ""}>YouTube video link
          <input name="externalUrl" type="url" inputmode="url" placeholder="https://www.youtube.com/watch?v=…" value="${escapeHtml(video?.external_url || "")}" ${video?.source_type === "upload" ? "" : "required"}>
          <small class="form-help">${video?.source_type === "upload" ? "This older uploaded video is retained. New video entries use YouTube links." : "Paste a YouTube video, Shorts, or youtu.be link. The thumbnail is added automatically."}</small>
        </label>
        <div id="video-thumbnail-preview" class="video-thumbnail-preview" hidden>
          <img alt="YouTube video thumbnail preview">
        </div>
        <div class="form-actions"><button type="button" class="button button-secondary" data-action="close-modal">Cancel</button>
          <button type="submit" class="button button-primary">${video ? "Save changes" : "Add video"}</button></div>
      </form>
    `);
    const form = document.querySelector("#video-editor");
    const preview = document.querySelector("#video-thumbnail-preview");
    const previewImage = preview.querySelector("img");
    const youtubeId = (value) => {
      try {
        const url = new URL(value);
        if (url.protocol !== "https:" || (url.port && url.port !== "443")) return "";
        const hostname = url.hostname.toLowerCase();
        const parts = url.pathname.split("/").filter(Boolean);
        let id = "";
        if (hostname === "youtu.be") id = parts[0] || "";
        else if (["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com"].includes(hostname)) {
          id = url.pathname === "/watch" ? url.searchParams.get("v") || "" : ["embed", "shorts", "live", "v"].includes(parts[0]) ? parts[1] || "" : "";
        }
        return /^[\w-]{11}$/.test(id) ? id : "";
      } catch {
        return "";
      }
    };
    const syncThumbnail = () => {
      const id = youtubeId(form.elements.externalUrl.value.trim());
      preview.hidden = !id;
      previewImage.src = id ? `https://i.ytimg.com/vi/${id}/hqdefault.jpg` : "";
    };
    form.elements.externalUrl.addEventListener("input", syncThumbnail);
    syncThumbnail();
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      const body = {
        title: form.elements.title.value,
        description: form.elements.description.value,
      };
      if (form.elements.externalUrl.value.trim()) body.externalUrl = form.elements.externalUrl.value.trim();
      try {
        await request(video ? `/api/admin/videos/${video.id}` : "/api/admin/videos", {
          method: video ? "PATCH" : "POST",
          body: JSON.stringify(body),
        });
        closeModal();
        showToast(video ? "Video updated." : "Video added.");
        await renderVideos();
      } catch (error) {
        showToast(error.message, true);
      }
    });
  }

  async function renderCategories() {
    const { categories } = await request("/api/admin/categories");
    state.categories = categories.filter((category) => !category.parent_id);
    const rows = categories.map((category) => `
      <tr>
        <td>${escapeHtml(category.parent_name ? `↳ ${category.parent_name} / ` : "")}${escapeHtml(category.name)}</td>
        <td>${escapeHtml(category.slug)}</td>
        <td>${escapeHtml(category.slug === "video-podcast" ? "Video cards" : categoryLayouts[category.homepage_layout] || category.homepage_layout)}</td>
        <td>${category.published_articles} published · ${category.article_count} total</td>
        <td><span class="status-pill ${category.is_enabled ? "status-active" : "status-suspended"}">${category.is_enabled ? "Enabled" : "Disabled"}</span></td>
        <td><div class="row-actions">
          <button class="button button-secondary" data-action="edit-category" data-id="${category.id}">Edit</button>
          <button class="button button-secondary" data-action="category-toggle" data-id="${category.id}" data-enabled="${!category.is_enabled}">${category.is_enabled ? "Disable" : "Enable"}</button>
          <button class="button button-danger" data-action="delete-category" data-id="${category.id}">Delete</button>
        </div></td>
      </tr>
    `).join("");
    const renderOrderList = (listId, items) => `
      <ol class="category-order-list" data-order-list="${listId}">
        ${items.map((category, index) => `
          <li data-category-id="${category.id}" class="${category.parent_id ? "is-subcategory" : ""}">
            <span>${escapeHtml(category.parent_name ? `${category.parent_name} / ` : "")}${escapeHtml(category.name)}</span>
            <span class="category-order-actions">
              <button class="button button-secondary" type="button" data-action="move-category" data-list="${listId}" data-direction="up" aria-label="Move ${escapeHtml(category.name)} up" ${index === 0 ? "disabled" : ""}>↑</button>
              <button class="button button-secondary" type="button" data-action="move-category" data-list="${listId}" data-direction="down" aria-label="Move ${escapeHtml(category.name)} down" ${index === items.length - 1 ? "disabled" : ""}>↓</button>
            </span>
          </li>
        `).join("")}
      </ol>
    `;
    const navbarCategories = [...categories].sort((a, b) => a.nav_sort_order - b.nav_sort_order || a.name.localeCompare(b.name));
    const homepageCategories = categories
      .filter((category) => !category.parent_id)
      .sort((a, b) => a.homepage_sort_order - b.homepage_sort_order || a.name.localeCompare(b.name));
    pageContent.innerHTML = `
      ${setHeading("Categories", "Organize categories, their homepage presentation, and their public order.",
        '<button class="button button-primary" data-action="new-category">＋ Add category</button>')}
      <div class="category-order-grid">
        <section class="panel category-order-panel">
          <h2>Navbar order</h2><p class="form-help">Controls the order of categories in the public navigation.</p>
          ${renderOrderList("navbar", navbarCategories)}
        </section>
        <section class="panel category-order-panel">
          <h2>Homepage order</h2><p class="form-help">Controls the order of top-level category sections on the homepage.</p>
          ${renderOrderList("homepage", homepageCategories)}
        </section>
      </div>
      <div class="form-actions category-order-save"><button class="button button-primary" data-action="save-category-orders">Save both orders</button></div>
      <div class="table-panel"><div class="table-scroll"><table><thead><tr><th>Category</th><th>URL slug</th><th>Homepage layout</th><th>Articles</th><th>Status</th><th>Actions</th></tr></thead>
        <tbody>${rows || `<tr><td colspan="6">${emptyPanel("No categories found.")}</td></tr>`}</tbody></table></div></div>
    `;
  }

  async function openCategoryEditor(categoryId = "") {
    const { categories } = await request("/api/admin/categories");
    const category = categoryId ? categories.find((item) => item.id === categoryId) : null;
    const parents = categories.filter((item) => !item.parent_id && item.id !== categoryId);
    openModal(category ? "Edit category" : "Add category", `
      <form id="category-editor" class="stack-form">
        <label>Name <input name="name" maxlength="100" required value="${escapeHtml(category?.name || "")}"></label>
        <label>URL slug <input name="slug" maxlength="100" pattern="[a-z0-9]+(-[a-z0-9]+)*" required value="${escapeHtml(category?.slug || "")}">
          <small class="form-help">Use lowercase English letters, numbers and hyphens.</small>
        </label>
        <label>Parent category
          <select name="parentId"><option value="">Top-level category</option>
            ${parents.map((parent) => `<option value="${parent.id}" ${category?.parent_id === parent.id ? "selected" : ""}>${escapeHtml(parent.name)}</option>`).join("")}
          </select>
        </label>
        ${category?.slug === "video-podcast" ? `
          <p class="form-help">This category is video-only; published video cards are used instead of article layouts.</p>
        ` : `<label>Homepage display
          <select name="homepageLayout">
            ${Object.entries(categoryLayouts).map(([value, label]) => `
              <option value="${value}" ${category?.homepage_layout === value || (!category && value === "lead-headlines") ? "selected" : ""}>${escapeHtml(label)}</option>
            `).join("")}
          </select>
        </label>`}
        ${category ? `<label class="inline-toggle"><input name="isEnabled" type="checkbox" ${category.is_enabled ? "checked" : ""}><span class="toggle-track"></span> Enabled</label>` : ""}
        <div class="form-actions"><button type="button" class="button button-secondary" data-action="close-modal">Cancel</button>
          <button type="submit" class="button button-primary">${category ? "Save category" : "Create category"}</button></div>
      </form>
    `);
    document.querySelector("#category-editor").addEventListener("submit", async (event) => {
      event.preventDefault();
      const form = event.currentTarget;
      const data = {
        name: form.elements.name.value,
        slug: form.elements.slug.value,
        parentId: form.elements.parentId.value || null,
      };
      if (form.elements.homepageLayout) data.homepageLayout = form.elements.homepageLayout.value;
      if (category) data.isEnabled = form.elements.isEnabled.checked;
      try {
        await request(category ? `/api/admin/categories/${category.id}` : "/api/admin/categories", {
          method: category ? "PATCH" : "POST",
          body: JSON.stringify(data),
        });
        closeModal();
        showToast("Category saved.");
        await renderCategories();
      } catch (error) {
        showToast(error.message, true);
      }
    });
  }

  async function renderSections() {
    const [sectionData, articleData] = await Promise.all([
      request("/api/admin/sections"),
      request("/api/admin/articles?status=published&limit=100"),
    ]);
    const available = articleData.articles.filter((article) => article.category_slug !== "video-podcast");
    pageContent.innerHTML = `
      ${setHeading("Homepage sections", "Choose which editorial sections appear on the public homepage.")}
      ${sectionData.sections.map((section) => `
        <form class="panel section-card" data-section-id="${section.id}">
          <div class="section-card-header">
            <div><h2>${escapeHtml(section.title)}</h2><small class="form-help">/${escapeHtml(section.slug)}</small></div>
            <label class="inline-toggle"><input name="isEnabled" type="checkbox" ${section.is_enabled ? "checked" : ""}><span class="toggle-track"></span> ${section.is_enabled ? "On" : "Off"}</label>
          </div>
          <div class="form-grid">
            <label>Section title <input name="title" maxlength="120" value="${escapeHtml(section.title)}"></label>
            <label>Display order <input name="sortOrder" type="number" min="0" max="1000" value="${section.sort_order}"></label>
            <label class="full-width">Description <input name="description" maxlength="500" value="${escapeHtml(section.description)}"></label>
            <div class="full-width"><label>Featured published articles</label>
              <div class="article-checklist">
                ${available.length ? available.map((article) => `
                  <label><input type="checkbox" name="articleIds" value="${article.id}" ${section.articles.some((item) => item.id === article.id) ? "checked" : ""}>
                  ${escapeHtml(article.title)}</label>
                `).join("") : emptyPanel("Publish an article before featuring it here.")}
              </div>
            </div>
          </div>
          <div class="form-actions"><button class="button button-primary" type="submit">Save section</button></div>
        </form>
      `).join("") || emptyPanel("No homepage sections are configured.")}
    `;
    document.querySelectorAll(".section-card").forEach((form) => {
      form.addEventListener("submit", async (event) => {
        event.preventDefault();
        const formData = new FormData(form);
        const articleIds = formData.getAll("articleIds");
        try {
          await request(`/api/admin/sections/${form.dataset.sectionId}`, {
            method: "PATCH",
            body: JSON.stringify({
              title: formData.get("title"),
              description: formData.get("description"),
              sortOrder: Number(formData.get("sortOrder")),
              isEnabled: form.elements.isEnabled.checked,
              articleIds,
            }),
          });
          showToast("Homepage section saved.");
        } catch (error) {
          showToast(error.message, true);
        }
      });
    });
  }

  async function renderUsers() {
    const { users } = await request("/api/admin/users");
    const rows = users.map((user) => {
      const actions = [];
      if (state.user.role === "super_admin" && user.id !== state.user.id) {
        actions.push(
          `<button class="button button-secondary" data-action="edit-user" data-id="${user.id}">Edit access</button>`,
          `<button class="button button-secondary" data-action="reset-password" data-id="${user.id}">Reset password</button>`,
          `<button class="button button-secondary" data-action="user-activity" data-id="${user.id}">Activity</button>`,
        );
      }
      return `<tr>
        <td><div><strong>${escapeHtml(user.username)}</strong><small class="muted-cell">${escapeHtml(user.email)}</small></div></td>
        <td>${escapeHtml(roles[user.role])}</td><td>${statusPill(user.status)}</td>
        <td>${user.active_sessions ? `${user.active_sessions} active` : "—"}</td>
        <td>${date(user.last_login_at)}</td><td><div class="row-actions">${actions.join("") || "—"}</div></td>
      </tr>`;
    }).join("");
    pageContent.innerHTML = `
      ${setHeading("User management", state.user.role === "super_admin" ? "Manage staff accounts, roles, and active access." : "View registered accounts and create Moderator accounts.",
        '<button class="button button-primary" data-action="new-user">＋ Create user</button>')}
      <div class="table-panel"><div class="table-scroll"><table><thead><tr><th>Account</th><th>Role</th><th>Status</th><th>Sessions</th><th>Last sign in</th><th>Actions</th></tr></thead>
        <tbody>${rows || `<tr><td colspan="6">${emptyPanel("No accounts found.")}</td></tr>`}</tbody></table></div></div>
    `;
  }

  async function renderSettings() {
    const { settings } = await request("/api/admin/settings");
    pageContent.innerHTML = `
      ${setHeading("Site settings", "Update the contact details and social links shown on the public website.")}
      <form id="site-settings-form" class="panel section-card stack-form">
        <div class="form-grid">
          <label>Site name <input name="site_name" maxlength="100" required value="${escapeHtml(settings.site_name || "")}"></label>
          <label>Contact email <input name="contact_email" type="email" maxlength="254" required value="${escapeHtml(settings.contact_email || "")}"></label>
          <label>Facebook URL <input name="facebook_url" type="url" placeholder="https://facebook.com/…" value="${escapeHtml(settings.facebook_url || "")}"></label>
          <label>YouTube URL <input name="youtube_url" type="url" placeholder="https://youtube.com/…" value="${escapeHtml(settings.youtube_url || "")}"></label>
          <label>Instagram URL <input name="instagram_url" type="url" placeholder="https://instagram.com/…" value="${escapeHtml(settings.instagram_url || "")}"></label>
        </div>
        <p class="form-help">Social links are optional. Leave a field blank to hide its icon from the public site.</p>
        <div class="form-actions"><button type="submit" class="button button-primary">Save settings</button></div>
      </form>
    `;
    document.querySelector("#site-settings-form").addEventListener("submit", async (event) => {
      event.preventDefault();
      const form = event.currentTarget;
      try {
        await request("/api/admin/settings", {
          method: "PATCH",
          body: JSON.stringify(Object.fromEntries(new FormData(form))),
        });
        showToast("Site settings saved.");
      } catch (error) {
        showToast(error.message, true);
      }
    });
  }

  async function openUserEditor(userId = "") {
    if (!userId) {
      openModal("Create user account", `
        <form id="user-create-form" class="stack-form">
          <label>Username <input name="username" minlength="3" maxlength="48" autocomplete="off" required></label>
          <label>Email <input name="email" type="email" maxlength="254" required></label>
          <label>Temporary password <input name="password" type="password" minlength="12" maxlength="72" required>
            <small class="form-help">At least 12 characters. Share the temporary password through a secure channel.</small>
          </label>
          ${state.user.role === "super_admin" ? `<label>Role <select name="role"><option value="moderator">Moderator</option><option value="admin">Admin</option><option value="super_admin">Super Admin</option></select></label>` : '<p class="form-help">New accounts created by an Admin receive the Moderator role.</p>'}
          <div class="form-actions"><button type="button" class="button button-secondary" data-action="close-modal">Cancel</button><button type="submit" class="button button-primary">Create account</button></div>
        </form>
      `);
      document.querySelector("#user-create-form").addEventListener("submit", async (event) => {
        event.preventDefault();
        const form = event.currentTarget;
        const body = {
          username: form.elements.username.value,
          email: form.elements.email.value,
          password: form.elements.password.value,
        };
        if (form.elements.role) body.role = form.elements.role.value;
        try {
          await request("/api/admin/users", { method: "POST", body: JSON.stringify(body) });
          closeModal();
          showToast("User account created.");
          await renderUsers();
        } catch (error) {
          showToast(error.message, true);
        }
      });
      return;
    }

    const { users } = await request("/api/admin/users");
    const user = users.find((item) => item.id === userId);
    if (!user) throw new Error("User account not found.");
    openModal("Edit account access", `
      <form id="user-edit-form" class="stack-form">
        <label>Username <input name="username" minlength="3" maxlength="48" required value="${escapeHtml(user.username)}"></label>
        <label>Email <input name="email" type="email" maxlength="254" required value="${escapeHtml(user.email)}"></label>
        <label>Role <select name="role">${Object.entries(roles).map(([role, name]) => `<option value="${role}" ${role === user.role ? "selected" : ""}>${name}</option>`).join("")}</select></label>
        <label>Account status <select name="status"><option value="active" ${user.status === "active" ? "selected" : ""}>Active</option><option value="suspended" ${user.status === "suspended" ? "selected" : ""}>Suspended</option></select></label>
        <p class="form-help">Suspending the account immediately invalidates all existing sessions.</p>
        <div class="form-actions"><button type="button" class="button button-secondary" data-action="close-modal">Cancel</button><button type="submit" class="button button-primary">Save account</button></div>
      </form>
    `);
    document.querySelector("#user-edit-form").addEventListener("submit", async (event) => {
      event.preventDefault();
      const form = event.currentTarget;
      try {
        await request(`/api/admin/users/${user.id}`, {
          method: "PATCH",
          body: JSON.stringify({
            username: form.elements.username.value,
            email: form.elements.email.value,
            role: form.elements.role.value,
            status: form.elements.status.value,
          }),
        });
        closeModal();
        showToast("Account updated.");
        await renderUsers();
      } catch (error) {
        showToast(error.message, true);
      }
    });
  }

  async function resetUserPassword(userId) {
    const password = window.prompt("Enter a new temporary password (at least 12 characters):");
    if (password === null) return;
    if (password.length < 12) {
      showToast("Password must contain at least 12 characters.", true);
      return;
    }
    if (!window.confirm("Reset this account's password and sign out all active sessions?")) return;
    await request(`/api/admin/users/${userId}/reset-password`, {
      method: "POST",
      body: JSON.stringify({ password }),
    });
    showToast("Password reset. Existing sessions were signed out.");
  }

  function bindPageEvents() {
    pageContent.addEventListener("click", async (event) => {
      const button = event.target.closest("[data-action]");
      if (!button) return;
      const { action, id, status } = button.dataset;
      try {
        if (action === "move-category") {
          const list = pageContent.querySelector(`[data-order-list="${button.dataset.list}"]`);
          const item = button.closest("li");
          const neighbor = button.dataset.direction === "up" ? item.previousElementSibling : item.nextElementSibling;
          if (neighbor) {
            if (button.dataset.direction === "up") list.insertBefore(item, neighbor);
            else list.insertBefore(neighbor, item);
            [...list.children].forEach((row, index) => {
              const [up, down] = row.querySelectorAll("button");
              up.disabled = index === 0;
              down.disabled = index === list.children.length - 1;
            });
          }
          return;
        }
        if (action === "save-category-orders") {
          const ids = (listId) => [...pageContent.querySelectorAll(`[data-order-list="${listId}"] > li`)]
            .map((item) => item.dataset.categoryId);
          await request("/api/admin/category-order", {
            method: "PUT",
            body: JSON.stringify({ navOrder: ids("navbar"), homepageOrder: ids("homepage") }),
          });
          showToast("Category orders saved.");
          await renderCategories();
        }
        if (action === "new-article") await openArticleEditor();
        if (action === "edit-article") await openArticleEditor(id);
        if (action === "preview-article") {
          const article = (await request(`/api/admin/articles/${id}`)).article;
          article.image_url = article.image_url || "";
          previewArticle(article);
        }
        if (action === "article-status") {
          const verb = status === "published" ? "publish" : "unpublish";
          if (!window.confirm(`Are you sure you want to ${verb} this article?`)) return;
          await request(`/api/admin/articles/${id}/status`, {
            method: "PATCH",
            body: JSON.stringify({ status }),
          });
          showToast(`Article ${status === "published" ? "published" : "unpublished"}.`);
          await renderArticles();
        }
        if (action === "delete-article") {
          if (!window.confirm("Delete this article permanently? This also removes it from homepage sections.")) return;
          await request(`/api/admin/articles/${id}`, { method: "DELETE" });
          showToast("Article deleted.");
          await renderArticles();
        }
        if (action === "reset-article-filters") {
          state.articleFilters = {};
          state.articleOffset = 0;
          await renderArticles();
        }
        if (action === "articles-prev") {
          state.articleOffset = Math.max(0, state.articleOffset - 50);
          await renderArticles();
        }
        if (action === "articles-next") {
          state.articleOffset += 50;
          await renderArticles();
        }
        if (action === "new-video") await openVideoEditor();
        if (action === "edit-video") await openVideoEditor(id);
        if (action === "video-status") {
          if (!window.confirm(`${status === "published" ? "Publish" : "Unpublish"} this video?`)) return;
          await request(`/api/admin/videos/${id}/status`, {
            method: "PATCH",
            body: JSON.stringify({ status }),
          });
          showToast("Video status updated.");
          await renderVideos();
        }
        if (action === "delete-video") {
          if (!window.confirm("Remove this video from the site?")) return;
          await request(`/api/admin/videos/${id}`, { method: "DELETE" });
          showToast("Video removed.");
          await renderVideos();
        }
        if (action === "new-category") await openCategoryEditor();
        if (action === "edit-category") await openCategoryEditor(id);
        if (action === "category-toggle") {
          const isEnabled = button.dataset.enabled === "true";
          await request(`/api/admin/categories/${id}`, {
            method: "PATCH",
            body: JSON.stringify({ isEnabled }),
          });
          showToast(`Category ${isEnabled ? "enabled" : "disabled"}.`);
          await renderCategories();
        }
        if (action === "delete-category") {
          if (!window.confirm("Delete this category? It cannot be deleted while it contains articles or subcategories.")) return;
          await request(`/api/admin/categories/${id}`, { method: "DELETE" });
          showToast("Category deleted.");
          await renderCategories();
        }
        if (action === "new-user") await openUserEditor();
        if (action === "edit-user") await openUserEditor(id);
        if (action === "reset-password") await resetUserPassword(id);
        if (action === "user-activity") await showUserActivity(id);
      } catch (error) {
        showToast(error.message, true);
      }
    });

    pageContent.addEventListener("submit", async (event) => {
      if (event.target.id !== "article-filters") return;
      event.preventDefault();
      const values = new FormData(event.target);
      state.articleFilters = Object.fromEntries([...values.entries()].filter(([, value]) => value));
      state.articleOffset = 0;
      await renderArticles();
    });

    modalContent.addEventListener("click", (event) => {
      const button = event.target.closest("[data-action]");
      if (!button) return;
      if (button.dataset.action === "close-modal") closeModal();
      if (button.dataset.action === "clear-article-image") {
        const form = document.querySelector("#article-editor");
        form.elements.imageKey.value = "";
        document.querySelector("#article-image-preview").removeAttribute("src");
        document.querySelector("#article-upload-status").textContent = "Article image removed.";
      }
    });
  }

  loginForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    loginError.textContent = "";
    const form = new FormData(loginForm);
    try {
      const data = await request("/api/auth/login", {
        method: "POST",
        body: JSON.stringify({
          username: form.get("username"),
          password: form.get("password"),
        }),
      });
      state.csrfToken = data.csrfToken;
      await showAdmin(data.user);
      loginForm.reset();
    } catch (error) {
      loginError.textContent = error.message;
    }
  });

  nav.addEventListener("click", async (event) => {
    const link = event.target.closest("[data-view]");
    if (!link) return;
    event.preventDefault();
    await navigate(link.dataset.view);
  });

  document.querySelector("#logout-button").addEventListener("click", async () => {
    try {
      await request("/api/auth/logout", { method: "POST" });
      showLogin();
    } catch (error) {
      showToast(error.message, true);
    }
  });

  document.querySelector("#modal-close").addEventListener("click", closeModal);
  modal.addEventListener("click", (event) => {
    if (event.target === modal) closeModal();
  });
  bindPageEvents();

  (async () => {
    try {
      await loadCsrf();
      const data = await request("/api/auth/me");
      await showAdmin(data.user);
    } catch (error) {
      showLogin();
      if (error.message !== "Authentication required.") {
        loginError.textContent = error.message;
      }
    }
  })();
})();
