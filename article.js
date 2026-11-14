(() => {
  const nav = document.querySelector("#category-nav");
  const articleView = document.querySelector("#article-detail");
  const slug = new URLSearchParams(location.search).get("slug");

  function showError(message) {
    const text = document.createElement("p");
    text.textContent = message;
    articleView.replaceChildren(text);
  }

  function renderBody(body) {
    const fragment = document.createDocumentFragment();
    body.split(/\n{2,}/).forEach((paragraph) => {
      if (!paragraph.trim()) return;
      const element = document.createElement("p");
      element.textContent = paragraph.trim();
      fragment.append(element);
    });
    return fragment;
  }

  async function render() {
    if (!slug) {
      showError("এই সংবাদটি পাওয়া যায়নি।");
      return;
    }

    let siteSettings = {};
    try {
      const [siteResponse, articleResponse] = await Promise.all([
        fetch("/api/public/site"),
        fetch(`/api/public/articles/${encodeURIComponent(slug)}`),
      ]);
      if (siteResponse.ok) {
        const site = await siteResponse.json();
        siteSettings = site.settings || {};
        if (site.settings?.contact_email) {
          const email = document.querySelector("#contact-email");
          email.href = `mailto:${site.settings.contact_email}`;
          email.textContent = site.settings.contact_email;
        }
        document.querySelectorAll("[data-setting]").forEach((link) => {
          const url = site.settings?.[link.dataset.setting];
          if (url) link.href = url;
        });
        const latest = document.createElement("a");
        latest.href = "index.html";
        latest.textContent = "সর্বশেষ সংবাদ";
        nav.append(latest);
        site.categories.forEach((category) => {
          const link = document.createElement("a");
          link.href = `index.html?category=${encodeURIComponent(category.slug)}`;
          const parent = site.categories.find((entry) => entry.id === category.parent_id);
          link.textContent = parent ? `${parent.name} / ${category.name}` : category.name;
          nav.append(link);
        });
      }
      if (!articleResponse.ok) {
        showError(articleResponse.status === 404 ? "এই সংবাদটি পাওয়া যায়নি।" : "সংবাদ লোড করা যায়নি।");
        return;
      }
      const { article } = await articleResponse.json();
      const siteName = siteSettings.site_name || "অনুসন্ধান";
      document.title = `${siteName} | ${article.title}`;
      const category = document.createElement("a");
      category.className = "article-category";
      category.href = `index.html?category=${encodeURIComponent(article.category_slug || "latest")}`;
      category.textContent = article.category || "সর্বশেষ সংবাদ";
      const title = document.createElement("h1");
      title.textContent = article.headline || article.title;
      const summary = document.createElement("p");
      summary.className = "article-summary";
      summary.textContent = article.summary;
      const meta = document.createElement("p");
      meta.className = "article-meta";
      meta.textContent = `${article.author} · ${new Intl.DateTimeFormat("bn-BD", {
        dateStyle: "long",
        timeStyle: "short",
      }).format(new Date(article.published_at))}`;
      const elements = [category, title, meta];
      if (article.summary) elements.push(summary);
      if (article.image) {
        const image = document.createElement("img");
        image.className = "article-hero-image";
        image.src = article.image;
        image.alt = article.image_alt || "";
        elements.push(image);
      }
      const body = document.createElement("div");
      body.className = "article-body";
      body.append(renderBody(article.body || ""));
      elements.push(body);
      articleView.replaceChildren(...elements);
    } catch {
      showError("সংবাদ সার্ভারের সঙ্গে সংযোগ করা যাচ্ছে না।");
    }
  }

  render();
})();
