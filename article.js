(() => {
  const nav = document.querySelector("#category-nav");
  const articleView = document.querySelector("#article-detail");
  const articlePathMatch = location.pathname.match(/^\/news\/([^/]+)\/?$/);
  let pathSlug = "";
  if (articlePathMatch) {
    try {
      pathSlug = decodeURIComponent(articlePathMatch[1]);
    } catch {
      pathSlug = articlePathMatch[1];
    }
  }
  const slug = new URLSearchParams(location.search).get("slug") || pathSlug;

  function showError(message) {
    const text = document.createElement("p");
    text.textContent = message;
    articleView.replaceChildren(text);
  }

  function renderBody(body) {
    const fragment = document.createDocumentFragment();
    let source = String(body || "");
    let parsed = new DOMParser().parseFromString(source, "text/html");
    if (/&lt;\/?(?:span|p|strong|b|em|i|u|h[2-3]|ul|ol|li|blockquote|a|br)\b/i.test(source)) {
      source = parsed.body.textContent;
      parsed = new DOMParser().parseFromString(source, "text/html");
    }
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
    if (/<\/?(p|h2|h3|strong|b|em|i|u|ul|ol|li|blockquote|a|br|span)\b/i.test(source)) {
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
        const headerAnnouncement = document.querySelector("#header-announcement");
        if (headerAnnouncement) {
          headerAnnouncement.textContent = siteSettings.header_text || "";
          headerAnnouncement.hidden = !siteSettings.header_text;
        }
        const footerNote = document.querySelector("#footer-note");
        if (footerNote) {
          footerNote.textContent = siteSettings.footer_text || "";
          footerNote.hidden = !siteSettings.footer_text;
        }
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
        latest.href = "/news";
        latest.textContent = "সর্বশেষ সংবাদ";
        nav.append(latest);
        site.categories.forEach((category) => {
          const link = document.createElement("a");
          link.href = `/category/${encodeURIComponent(category.name)}`;
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
      const description = article.summary || article.headline || article.title;
      const setMeta = (selector, content, attribute = "content") => {
        let element = document.head.querySelector(selector);
        if (!element) {
          element = document.createElement("meta");
          const [key, value] = selector.match(/\[(name|property)="([^"]+)"\]/).slice(1);
          element.setAttribute(key, value);
          document.head.append(element);
        }
        element.setAttribute(attribute, content || "");
      };
      setMeta('meta[name="description"]', description);
      setMeta('meta[property="og:title"]', article.title);
      setMeta('meta[property="og:description"]', description);
      if (article.image) setMeta('meta[property="og:image"]', article.image);
      let canonical = document.head.querySelector('link[rel="canonical"]');
      if (!canonical) {
        canonical = document.createElement("link");
        canonical.rel = "canonical";
        document.head.append(canonical);
      }
      canonical.href = `${location.origin}/news/${encodeURIComponent(article.slug)}`;
      let structured = document.head.querySelector('script[type="application/ld+json"]');
      if (!structured) {
        structured = document.createElement("script");
        structured.type = "application/ld+json";
        document.head.append(structured);
      }
      structured.textContent = JSON.stringify({
        "@context": "https://schema.org",
        "@type": "NewsArticle",
        headline: article.headline || article.title,
        description,
        datePublished: article.published_at,
        image: article.image || undefined,
        publisher: { "@type": "Organization", name: siteName },
        mainEntityOfPage: canonical.href,
      });
      const category = document.createElement("a");
      category.className = "article-category";
      category.href = article.category ? `/category/${encodeURIComponent(article.category)}` : "/news";
      category.textContent = article.category || "সর্বশেষ সংবাদ";
      const title = document.createElement("h1");
      title.textContent = article.headline || article.title;
      const summary = document.createElement("p");
      summary.className = "article-summary";
      summary.textContent = article.summary;
      const meta = document.createElement("p");
      meta.className = "article-meta";
      meta.textContent = new Intl.DateTimeFormat("bn-BD", {
        dateStyle: "long",
        timeStyle: "short",
      }).format(new Date(article.published_at));
      const elements = [category, title, meta];
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
