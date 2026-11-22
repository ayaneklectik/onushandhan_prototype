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
    const parsed = new DOMParser().parseFromString(String(body || ""), "text/html");
    const allowed = new Set(["P", "BR", "H2", "H3", "STRONG", "B", "EM", "I", "U", "UL", "OL", "LI", "BLOCKQUOTE", "A"]);
    const copySafe = (source, target) => {
      for (const child of source.childNodes) {
        if (child.nodeType === Node.TEXT_NODE) {
          target.append(document.createTextNode(child.textContent));
          continue;
        }
        if (child.nodeType !== Node.ELEMENT_NODE) continue;
        if (!allowed.has(child.tagName)) {
          copySafe(child, target);
          continue;
        }
        const element = document.createElement(child.tagName.toLowerCase());
        if (child.tagName === "A") {
          const href = child.getAttribute("href") || "";
          if (/^https:\/\//i.test(href)) {
            element.href = href;
            element.target = "_blank";
            element.rel = "noopener noreferrer";
          }
        }
        copySafe(child, element);
        target.append(element);
      }
    };
    if (/<\/?(p|h2|h3|strong|b|em|i|u|ul|ol|li|blockquote|a|br)\b/i.test(body || "")) {
      copySafe(parsed.body, fragment);
    } else {
      String(body || "").split(/\n{2,}/).forEach((paragraph) => {
        if (!paragraph.trim()) return;
        const element = document.createElement("p");
        element.textContent = paragraph.trim();
        fragment.append(element);
      });
    }
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
      const elements = [category, title];
      if (article.attribution) {
        const attribution = document.createElement("p");
        attribution.className = "article-attribution";
        attribution.textContent = article.attribution;
        elements.push(attribution);
      }
      elements.push(meta);
      if (article.summary) elements.push(summary);
      if (article.image) {
        const image = document.createElement("img");
        image.className = "article-hero-image";
        image.src = article.image;
        image.alt = article.image_alt || "";
        const figure = document.createElement("figure");
        figure.className = "article-hero-figure";
        figure.append(image);
        if (article.image_caption || article.image_credit) {
          const caption = document.createElement("figcaption");
          caption.className = "article-image-caption";
          caption.textContent = [article.image_caption, article.image_credit].filter(Boolean).join(" | ");
          figure.append(caption);
        }
        elements.push(figure);
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
