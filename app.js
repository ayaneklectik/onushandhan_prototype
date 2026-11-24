(() => {
  const params = new URLSearchParams(window.location.search);
  const categorySlug = params.get("category") || "latest";
  const searchQuery = params.get("q")?.trim() || "";
  const nav = document.querySelector("#category-nav");
  const pageTitle = document.querySelector("#page-title");
  const newsHeading = document.querySelector("#news-heading");
  const newsHeadingSection = newsHeading.closest(".section-heading");
  const newsList = document.querySelector("#news-list");
  const homepageSections = document.querySelector("#homepage-sections");
  const homeLayout = document.querySelector("#home-layout");
  const contentLayout = document.querySelector(".content-layout");
  const searchForm = document.querySelector("#site-search-form");
  const searchInput = document.querySelector("#site-search-input");
  const searchToggle = document.querySelector("#search-toggle");

  searchToggle.addEventListener("click", () => {
    const opening = searchForm.hidden;
    searchForm.hidden = !opening;
    searchToggle.setAttribute("aria-expanded", String(opening));
    searchToggle.setAttribute("aria-label", opening ? "অনুসন্ধান বন্ধ করুন" : "অনুসন্ধান খুলুন");
    if (opening) searchInput.focus();
  });
  searchForm.addEventListener("submit", (event) => {
    if (!searchInput.value.trim()) {
      event.preventDefault();
      searchInput.focus();
    }
  });

  function showMessage(message) {
    const emptyState = document.createElement("div");
    emptyState.className = "empty-state";
    const paragraph = document.createElement("p");
    paragraph.textContent = message;
    emptyState.append(paragraph);
    newsList.replaceChildren(emptyState);
  }

  function articleCard(article) {
    const card = document.createElement("article");
    card.className = "news-card";
    const link = document.createElement("a");
    link.className = "news-card-link";
    link.href = `article.html?slug=${encodeURIComponent(article.slug)}`;

    if (article.image) {
      const image = document.createElement("img");
      image.className = "news-image";
      image.src = article.image;
      image.alt = article.image_alt || article.imageAlt || "";
      image.loading = "lazy";
      link.append(image);
    }

    const title = document.createElement("h3");
    title.textContent = article.headline || article.title;
    link.append(title);
    if (article.summary) {
      const summary = document.createElement("p");
      summary.textContent = article.summary;
      link.append(summary);
    }
    card.append(link);
    return card;
  }

  function articleLink(article) {
    const link = document.createElement("a");
    link.className = "news-card-link";
    link.href = `article.html?slug=${encodeURIComponent(article.slug)}`;
    return link;
  }

  function categoryLink(category) {
    const link = document.createElement("a");
    link.className = "home-section-link";
    link.href = `index.html?category=${encodeURIComponent(category.slug)}`;
    link.textContent = "বিভাগে সব দেখুন →";
    return link;
  }

  function categoryName(article, categories) {
    return categories.find((category) => category.id === article.category_id)?.name
      || article.category
      || "";
  }

  function videoCard(video) {
    const card = document.createElement("article");
    card.className = "news-card video-card";
    if (video.youtubeVideoId) {
      card.append(makePlayButton(video));
    } else if (video.source_type === "upload" && video.videoUrl) {
      const player = document.createElement("video");
      player.className = "video-embed";
      player.controls = true;
      player.preload = "metadata";
      if (video.thumbnailUrl) player.poster = video.thumbnailUrl;
      const source = document.createElement("source");
      source.src = video.videoUrl;
      player.append(source);
      card.append(player);
    } else if (video.videoUrl) {
      const link = document.createElement("a");
      link.className = "news-card-link";
      link.href = video.videoUrl;
      link.target = "_blank";
      link.rel = "noreferrer";
      if (video.thumbnailUrl) {
        const image = document.createElement("img");
        image.className = "news-image";
        image.src = video.thumbnailUrl;
        image.alt = video.title;
        image.loading = "lazy";
        link.append(image);
      }
      card.append(link);
    }
    const title = document.createElement("h3");
    title.textContent = video.title;
    card.append(title);
    if (video.description) {
      const description = document.createElement("p");
      description.textContent = video.description;
      card.append(description);
    }
    return card;
  }

  function makePlayButton(video, className = "video-poster") {
    const poster = document.createElement("button");
    poster.className = className;
    poster.type = "button";
    poster.setAttribute("aria-label", `Play video: ${video.title}`);
    const image = document.createElement("img");
    image.className = "video-poster-image";
    image.src = video.thumbnailUrl;
    image.alt = video.title;
    image.loading = "lazy";
    poster.append(image);
    const playIcon = document.createElement("span");
    playIcon.className = "video-play-icon";
    playIcon.setAttribute("aria-hidden", "true");
    playIcon.textContent = "▶";
    poster.append(playIcon);
    poster.addEventListener("click", () => {
      const player = document.createElement("iframe");
      player.className = "video-embed";
      player.src = `https://www.youtube-nocookie.com/embed/${encodeURIComponent(video.youtubeVideoId)}?autoplay=1&rel=0`;
      player.title = video.title;
      player.allow = "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture";
      player.allowFullscreen = true;
      player.referrerPolicy = "strict-origin-when-cross-origin";
      poster.replaceWith(player);
    }, { once: true });
    return poster;
  }

  function leadStory(article, categories) {
    const card = document.createElement("article");
    card.className = "home-lead-story";
    const copy = document.createElement("div");
    copy.className = "home-lead-copy";
    const category = document.createElement("p");
    category.className = "story-category";
    category.textContent = categoryName(article, categories);
    copy.append(category);
    const titleLink = articleLink(article);
    const title = document.createElement("h2");
    title.textContent = article.headline || article.title;
    titleLink.append(title);
    copy.append(titleLink);
    if (article.summary) {
      const summary = document.createElement("p");
      summary.className = "home-lead-summary";
      summary.textContent = article.summary;
      copy.append(summary);
    }
    const imageLink = articleLink(article);
    imageLink.className = "home-lead-image-link";
    if (article.image) {
      const image = document.createElement("img");
      image.src = article.image;
      image.alt = article.image_alt || article.imageAlt || "";
      image.loading = "eager";
      imageLink.append(image);
    }
    card.append(copy, imageLink);
    return card;
  }

  function topStories(articles, categories) {
    const aside = document.createElement("aside");
    aside.className = "top-stories";
    const heading = document.createElement("h2");
    heading.textContent = "শীর্ষ সংবাদ";
    aside.append(heading);
    const list = document.createElement("ol");
    articles.forEach((article) => {
      const item = document.createElement("li");
      const link = articleLink(article);
      const category = document.createElement("span");
      category.className = "story-category";
      category.textContent = categoryName(article, categories);
      const title = document.createElement("strong");
      title.textContent = article.headline || article.title;
      link.append(category, title);
      item.append(link);
      list.append(item);
    });
    aside.append(list);
    return aside;
  }

  function latestStories(articles, categories) {
    const section = document.createElement("section");
    section.className = "home-latest-section";
    const heading = document.createElement("div");
    heading.className = "home-section-heading";
    const title = document.createElement("h2");
    title.textContent = "সর্বশেষ সংবাদ";
    heading.append(title);
    const list = document.createElement("div");
    list.className = "home-latest-grid";
    articles.forEach((article) => {
      const card = articleCard(article);
      const category = document.createElement("p");
      category.className = "story-category";
      category.textContent = categoryName(article, categories);
      card.prepend(category);
      list.append(card);
    });
    section.append(heading, list);
    return section;
  }

  function categorySection(category, articles, categories) {
    if (category.slug === "video-podcast") {
      if (!articles.length) return null;
      const section = document.createElement("section");
      section.className = "home-category-section home-video-category-section";
      const heading = document.createElement("div");
      heading.className = "home-section-heading";
      const title = document.createElement("h2");
      title.textContent = category.name;
      heading.append(title, categoryLink(category));
      const grid = document.createElement("div");
      grid.className = "home-video-category-grid";
      articles.forEach((video) => grid.append(videoCard(video)));
      section.append(heading, grid);
      return section;
    }

    if (!articles.length) return null;
    const section = document.createElement("section");
    const mosaicCategories = ["reports", "opinion", "power-and-influence", "content-stories"];
    const layout = mosaicCategories.includes(category.slug) ? "image-mosaic" : category.homepage_layout || "lead-headlines";
    section.className = `home-category-section layout-${layout}`;
    const heading = document.createElement("div");
    heading.className = "home-section-heading";
    const title = document.createElement("h2");
    title.textContent = category.name;
    heading.append(title, categoryLink(category));
    const body = document.createElement("div");
    body.className = "home-category-body";

    if (layout === "image-mosaic") {
      const grid = document.createElement("div");
      grid.className = "home-mosaic-grid";

      const lead = articles[0];
      const leadCard = articleCard(lead);
      leadCard.classList.add("home-mosaic-feature");
      const leadCategory = document.createElement("p");
      leadCategory.className = "story-category";
      leadCategory.textContent = categoryName(lead, categories);
      leadCard.prepend(leadCategory);

      const supporting = document.createElement("div");
      supporting.className = "home-mosaic-list";
      articles.slice(1, 7).forEach((article) => {
        const link = articleLink(article);
        link.className = "home-mosaic-item";
        if (article.image) {
          const image = document.createElement("img");
          image.src = article.image;
          image.alt = article.image_alt || article.imageAlt || "";
          image.loading = "lazy";
          link.append(image);
        }
        const copy = document.createElement("div");
        const headline = document.createElement("h3");
        headline.textContent = article.headline || article.title;
        copy.append(headline);
        link.append(copy);
        supporting.append(link);
      });

      grid.append(leadCard, supporting);
      body.append(grid);
      section.append(heading, body);
      return section;
    }

    if (layout === "image-grid") {
      const grid = document.createElement("div");
      grid.className = "home-category-grid";
      articles.forEach((article) => grid.append(articleCard(article)));
      body.append(grid);
      section.append(heading, body);
      return section;
    }

    if (layout === "headline-list") {
      const headlines = document.createElement("div");
      headlines.className = "home-category-headlines";
      articles.forEach((article) => {
        const link = articleLink(article);
        const headline = document.createElement("h3");
        headline.textContent = article.headline || article.title;
        link.append(headline);
        headlines.append(link);
      });
      body.append(headlines);
      section.append(heading, body);
      return section;
    }

    const lead = articles[0];
    const leadCard = articleCard(lead);
    leadCard.classList.add("home-category-lead");
    const leadCategory = document.createElement("p");
    leadCategory.className = "story-category";
    leadCategory.textContent = categoryName(lead, categories);
    leadCard.prepend(leadCategory);
    const otherStories = document.createElement("div");
    otherStories.className = "home-category-headlines";
    articles.slice(1, 7).forEach((article) => {
      const link = articleLink(article);
      const titleLink = document.createElement("h3");
      titleLink.textContent = article.headline || article.title;
      link.append(titleLink);
      if (layout !== "feature-headlines" && article.summary) {
        const summary = document.createElement("p");
        summary.textContent = article.summary;
        link.append(summary);
      }
      otherStories.append(link);
    });
    body.append(leadCard, otherStories);
    section.append(heading, body);
    return section;
  }

  function placementBlock(title, items, className = "") {
    if (!items?.length) return null;
    const section=document.createElement("section");
    section.className=`homepage-section editorial-placement ${className}`;
    const heading=document.createElement("div"); heading.className="section-heading";
    const label=document.createElement("h2"); label.textContent=title;
    const rule=document.createElement("span"); rule.className="heading-rule"; rule.setAttribute("aria-hidden","true");
    heading.append(label,rule); section.append(heading);
    const list=document.createElement("div"); list.className="news-list";
    items.forEach(article=>list.append(articleCard(article)));
    section.append(list); return section;
  }

  function contentEntryBlock(title, entries, isAds = false) {
    if (!entries?.length) return null;
    const section=document.createElement("section"); section.className=isAds?"homepage-section sponsored-content":"homepage-section editorial-writings";
    const heading=document.createElement("div"); heading.className="section-heading";
    const h=document.createElement("h2"); h.textContent=title;
    const rule=document.createElement("span"); rule.className="heading-rule"; rule.setAttribute("aria-hidden","true");
    heading.append(h,rule); section.append(heading);
    const grid=document.createElement("div"); grid.className="news-list";
    entries.forEach(entry=>{
      const card=document.createElement("article"); card.className="news-card";
      if(entry.image_url){const img=document.createElement("img");img.src=entry.image_url;img.alt=entry.title;img.loading="lazy";card.append(img);}
      const body=document.createElement("div"); body.className="news-card-content";
      const titleNode=document.createElement("h3");
      if(entry.target_url){const link=document.createElement("a");link.href=entry.target_url;link.textContent=entry.title;link.rel="noopener noreferrer";titleNode.append(link);}
      else titleNode.textContent=entry.title;
      body.append(titleNode);
      if(entry.content){const description=document.createElement("p");description.textContent=entry.content;body.append(description);}
      card.append(body);grid.append(card);
    });
    section.append(grid); return section;
  }

  function homePage(data, articles) {
    document.body.classList.add("is-home");
    contentLayout.classList.add("is-home-layout");
    homeLayout.hidden = false;
    newsHeadingSection.hidden = true;
    newsList.hidden = true;
    homepageSections.replaceChildren();

    const sections = [...data.sections].sort((a, b) => a.sort_order - b.sort_order);
    if (!articles.length && !data.videos.length && !sections.some((section) => section.articles.length) && !Object.values(data.placements || {}).some(items => items.length) && !(data.contentEntries || []).length) {
      const emptyState = document.createElement("div");
      emptyState.className = "empty-state";
      const message = document.createElement("p");
      message.textContent = "এই মুহূর্তে কোনো সংবাদ প্রকাশিত নেই।";
      emptyState.append(message);
      homeLayout.replaceChildren(emptyState);
      return;
    }
    const selectedArticles = sections.flatMap((section) => section.articles);
    const selectedIds = new Set(selectedArticles.map((article) => article.id));
    const available = articles.filter((article) => !selectedIds.has(article.id));
    const lead = available.shift() || articles[0];
    const usedIds = new Set([lead?.id, ...selectedIds].filter(Boolean));
    const remaining = articles.filter((article) => !usedIds.has(article.id));
    const leadGrid = document.createElement("section");
    leadGrid.className = "home-lead-grid";
    if (lead) leadGrid.append(leadStory(lead, data.categories));
    if (data.videos[0]) {
      if (!lead) leadGrid.classList.add("is-video-only");
      const live = document.createElement("div");
      live.className = "home-live-video";
      const badge = document.createElement("p");
      badge.className = "live-badge";
      badge.textContent = "● ভিডিও";
      live.append(badge, videoCard(data.videos[0]));
      leadGrid.append(live);
    }
    homeLayout.append(leadGrid);

    const placementLabels = [
      ["top", "শীর্ষ সংবাদ", "is-top-news"],
      ["breaking", "ব্রেকিং নিউজ", "is-breaking"],
      ["popular", "জনপ্রিয় সংবাদ", "is-popular"],
      ["special", "বিশেষ প্রতিবেদন", "is-special"],
      ["recent", "সাম্প্রতিক", "is-recent"],
    ];
    placementLabels.forEach(([key,label,className]) => {
      const block=placementBlock(label,data.placements?.[key],className);
      if(block) homeLayout.append(block);
    });

    const lower = document.createElement("div");
    lower.className = "home-lower-grid";
    if (remaining.length) {
      const latestArticles = remaining.slice(0, 8);
      const topArticles = remaining.slice(8, 15);
      const latest = latestStories(latestArticles, data.categories);
      lower.append(latest);
      if (topArticles.length) lower.append(topStories(topArticles, data.categories));
      homeLayout.append(lower);
    }

    data.categories
      .filter((category) => !category.parent_id)
      .sort((a, b) => a.homepage_sort_order - b.homepage_sort_order)
      .forEach((category) => {
        if (category.slug === "video-podcast") {
          const section = categorySection(category, data.videos.slice(0, 7), data.categories);
          if (section) homeLayout.append(section);
          return;
        }
        const childIds = data.categories.filter((item) => item.parent_id === category.id).map((item) => item.id);
        const allCategoryArticles = articles.filter(
          (article) => article.category_id === category.id || childIds.includes(article.category_id),
        );
        const section = categorySection(category, allCategoryArticles.slice(0, 7), data.categories);
        if (section) homeLayout.append(section);
      });

    sections.forEach((section) => {
      const element = sectionBlock(section);
      if (element) homeLayout.append(element);
    });
    const writings = (data.contentEntries || []).filter(entry => entry.module === "writings");
    const ads = (data.contentEntries || []).filter(entry => entry.module === "ads");
    const writingBlock = contentEntryBlock("লেখালেখি", writings);
    const adsBlock = contentEntryBlock("বিজ্ঞাপন", ads, true);
    if (writingBlock) homeLayout.append(writingBlock);
    if (adsBlock) homeLayout.append(adsBlock);
  }

  function sectionBlock(section) {
    if (!section.articles.length) return null;
    const container = document.createElement("section");
    container.className = "homepage-section";
    const heading = document.createElement("div");
    heading.className = "section-heading";
    const title = document.createElement("h2");
    title.textContent = section.title;
    heading.append(title);
    const rule = document.createElement("span");
    rule.className = "heading-rule";
    rule.setAttribute("aria-hidden", "true");
    heading.append(rule);
    container.append(heading);
    if (section.description) {
      const description = document.createElement("p");
      description.className = "homepage-section-description";
      description.textContent = section.description;
      container.append(description);
    }
    const list = document.createElement("div");
    list.className = "news-list";
    section.articles.forEach((article) => list.append(articleCard(article)));
    container.append(list);
    return container;
  }

  async function render() {
    let data;
    try {
      const response = await fetch("/api/public/site", { headers: { Accept: "application/json" } });
      if (!response.ok) throw new Error();
      data = await response.json();
    } catch {
      document.title = "অনুসন্ধান | সংযোগ পাওয়া যায়নি";
      pageTitle.textContent = "সংবাদ লোড করা যায়নি";
      newsHeading.textContent = "সংবাদ লোড করা যায়নি";
      showMessage("সংবাদ সার্ভারের সঙ্গে সংযোগ করা যাচ্ছে না। কিছুক্ষণ পরে আবার চেষ্টা করুন।");
      return;
    }

    const categories = [{ slug: "latest", name: "সর্বশেষ সংবাদ", id: null }, ...data.categories];
    const headerAnnouncement = document.querySelector("#header-announcement");
    if (headerAnnouncement) {
      headerAnnouncement.textContent = data.settings?.header_text || "";
      headerAnnouncement.hidden = !data.settings?.header_text;
    }
    const footerNote = document.querySelector("#footer-note");
    if (footerNote) {
      footerNote.textContent = data.settings?.footer_text || "";
      footerNote.hidden = !data.settings?.footer_text;
    }
    if (data.settings?.contact_email) {
      const email = document.querySelector("#contact-email");
      email.href = `mailto:${data.settings.contact_email}`;
      email.textContent = data.settings.contact_email;
    }
    document.querySelectorAll("[data-setting]").forEach((link) => {
      const url = data.settings?.[link.dataset.setting];
      link.hidden = !url;
      if (url) link.href = url;
    });
    document.querySelector(".header-social-links").hidden =
      !data.settings?.facebook_url && !data.settings?.youtube_url && !data.settings?.instagram_url;
    document.querySelector(".social-links").hidden =
      !data.settings?.facebook_url && !data.settings?.youtube_url && !data.settings?.instagram_url;
    document.querySelector(".sidebar").hidden = !data.settings?.facebook_url;
    searchInput.value = searchQuery;
    categories.forEach((item) => {
      const link = document.createElement("a");
      link.href =
        item.slug === "latest"
          ? "index.html"
          : `index.html?category=${encodeURIComponent(item.slug)}`;
      const parent = data.categories.find((entry) => entry.id === item.parent_id);
      link.textContent = parent ? `${parent.name} / ${item.name}` : item.name;
      if (item.slug === categorySlug) {
        link.classList.add("is-active");
        link.setAttribute("aria-current", "page");
      }
      nav.append(link);
    });

    if (searchQuery) {
      const terms = searchQuery.toLocaleLowerCase().split(/\s+/).filter(Boolean);
      const results = data.articles.filter((article) => {
        const searchable = `${article.title} ${article.headline} ${article.summary}`.toLocaleLowerCase();
        return terms.every((term) => searchable.includes(term));
      });
      document.body.classList.remove("is-home");
      contentLayout.classList.remove("is-home-layout");
      homeLayout.hidden = true;
      newsHeadingSection.hidden = false;
      newsList.hidden = false;
      homepageSections.replaceChildren();
      pageTitle.textContent = `অনুসন্ধান: ${searchQuery}`;
      newsHeading.textContent = results.length ? `অনুসন্ধানের ফলাফল (${results.length})` : "কোনো ফল পাওয়া যায়নি";
      document.title = `অনুসন্ধান | ${searchQuery}`;
      if (results.length) results.forEach((article) => newsList.append(articleCard(article)));
      else showMessage("এই শব্দে কোনো প্রকাশিত সংবাদ পাওয়া যায়নি। অন্য শব্দ দিয়ে খুঁজুন।");
      return;
    }

    const category = categories.find((item) => item.slug === categorySlug);
    if (!category) {
      document.title = "অনুসন্ধান | বিভাগ পাওয়া যায়নি";
      pageTitle.textContent = "বিভাগ পাওয়া যায়নি";
      newsHeading.textContent = "বিভাগটি খুঁজে পাওয়া যায়নি";
      showMessage("আপনার খোঁজা বিভাগটি পাওয়া যায়নি।");
      return;
    }

    pageTitle.textContent = category.name;
    newsHeading.textContent = category.name;
    document.title = `${data.settings?.site_name || "অনুসন্ধান"} | ${category.name}`;

    let articles = data.articles;
    const videos = categorySlug === "video-podcast" ? data.videos : [];
    if (categorySlug === "latest") {
      homePage(data, articles);
      return;
    }
    homeLayout.hidden = true;
    newsHeadingSection.hidden = false;
    newsList.hidden = false;
    homepageSections.replaceChildren();
    document.body.classList.remove("is-home");
    contentLayout.classList.remove("is-home-layout");
    if (categorySlug === "video-podcast") {
      articles = [];
      newsList.classList.add("video-category-list");
    } else {
      newsList.classList.remove("video-category-list");
    }
    if (categorySlug !== "latest" && categorySlug !== "video-podcast") {
      const childIds = data.categories
        .filter((item) => item.parent_id === category.id)
        .map((item) => item.id);
      articles = articles.filter(
        (article) => article.category_id === category.id || childIds.includes(article.category_id),
      );
    }

    if (!articles.length && !videos.length) {
      showMessage("এই বিভাগে এখনো কোনো সংবাদ প্রকাশিত হয়নি।");
      return;
    }
    articles.forEach((article) => newsList.append(articleCard(article)));
    videos.forEach((video) => newsList.append(videoCard(video)));
    if (!articles.length && videos.length) newsList.hidden = false;
  }

  render();
})();
