--
-- PostgreSQL database dump
--

\restrict Ayi48NJm5dpkkAHGaZ1vo0ZuhReylCdbZor49ZN8T1zV7aRz1RdzFiyIiLSWF5k

-- Dumped from database version 18.7 (Debian 18.7-1.pgdg13+5)
-- Dumped by pg_dump version 18.7 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: activity_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_log (
    id bigint NOT NULL,
    actor_id uuid,
    action text NOT NULL,
    entity_type text NOT NULL,
    entity_id text,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: activity_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.activity_log ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.activity_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: admin_content_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_content_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    module text NOT NULL,
    title text NOT NULL,
    content text DEFAULT ''::text NOT NULL,
    target_url text DEFAULT ''::text NOT NULL,
    image_url text DEFAULT ''::text NOT NULL,
    placement text DEFAULT ''::text NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT admin_content_entries_module_check CHECK ((module = ANY (ARRAY['writings'::text, 'ads'::text])))
);


--
-- Name: admin_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    token_hash text NOT NULL,
    csrf_hash text NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL
);


--
-- Name: article_placements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.article_placements (
    article_id uuid NOT NULL,
    placement text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT article_placements_placement_check CHECK ((placement = ANY (ARRAY['top'::text, 'recent'::text, 'breaking'::text, 'popular'::text, 'special'::text])))
);


--
-- Name: articles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.articles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug text NOT NULL,
    title text NOT NULL,
    headline text DEFAULT ''::text NOT NULL,
    summary text DEFAULT ''::text NOT NULL,
    body text DEFAULT ''::text NOT NULL,
    image_key text,
    image_alt text DEFAULT ''::text NOT NULL,
    category_id uuid,
    status text DEFAULT 'draft'::text NOT NULL,
    author_id uuid NOT NULL,
    published_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    attribution text DEFAULT ''::text NOT NULL,
    image_caption text DEFAULT ''::text NOT NULL,
    image_credit text DEFAULT ''::text NOT NULL,
    CONSTRAINT articles_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'published'::text, 'unpublished'::text])))
);


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    parent_id uuid,
    is_enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    nav_sort_order integer DEFAULT 1000 NOT NULL,
    homepage_sort_order integer DEFAULT 1000 NOT NULL,
    homepage_layout text DEFAULT 'lead-headlines'::text NOT NULL,
    CONSTRAINT categories_check CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT categories_homepage_layout_check CHECK ((homepage_layout = ANY (ARRAY['lead-headlines'::text, 'feature-headlines'::text, 'image-grid'::text, 'headline-list'::text])))
);


--
-- Name: media_assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.media_assets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    object_key text NOT NULL,
    media_type text NOT NULL,
    content_type text NOT NULL,
    size_bytes bigint NOT NULL,
    status text DEFAULT 'uploading'::text NOT NULL,
    uploader_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT media_assets_media_type_check CHECK ((media_type = ANY (ARRAY['image'::text, 'video'::text]))),
    CONSTRAINT media_assets_size_bytes_check CHECK ((size_bytes > 0)),
    CONSTRAINT media_assets_status_check CHECK ((status = ANY (ARRAY['uploading'::text, 'ready'::text])))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    filename text NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: section_articles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.section_articles (
    section_id uuid NOT NULL,
    article_id uuid NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL
);


--
-- Name: site_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.site_sections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug text NOT NULL,
    title text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: site_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.site_settings (
    setting_key text NOT NULL,
    setting_value text NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: test_seed_articles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.test_seed_articles (
    article_id uuid NOT NULL,
    category_id uuid NOT NULL,
    seed_version text DEFAULT 'v1'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: test_seed_assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.test_seed_assets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    object_key text NOT NULL,
    media_asset_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    username text NOT NULL,
    email text NOT NULL,
    password_hash text NOT NULL,
    role text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_login_at timestamp with time zone,
    avatar_url text DEFAULT ''::text NOT NULL,
    CONSTRAINT users_role_check CHECK ((role = ANY (ARRAY['super_admin'::text, 'admin'::text, 'moderator'::text]))),
    CONSTRAINT users_status_check CHECK ((status = ANY (ARRAY['active'::text, 'suspended'::text])))
);


--
-- Name: videos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.videos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    source_type text NOT NULL,
    object_key text,
    external_url text,
    thumbnail_key text,
    status text DEFAULT 'draft'::text NOT NULL,
    author_id uuid NOT NULL,
    published_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT videos_check CHECK ((((source_type = 'upload'::text) AND (object_key IS NOT NULL) AND (external_url IS NULL)) OR ((source_type = 'external'::text) AND (external_url IS NOT NULL)))),
    CONSTRAINT videos_source_type_check CHECK ((source_type = ANY (ARRAY['upload'::text, 'external'::text]))),
    CONSTRAINT videos_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'published'::text, 'unpublished'::text])))
);


--
-- Data for Name: activity_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.activity_log (id, actor_id, action, entity_type, entity_id, details, created_at) FROM stdin;
1	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	created	user	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	{"role": "super_admin", "bootstrap": true}	2026-11-14 18:01:19.846144+00
2	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	login	session	e1d6228a-2658-48d8-a028-2629f1c1da49	{}	2026-11-14 18:01:36.083661+00
3	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	login	session	3796925a-5387-45ac-81e5-f874c28f9907	{}	2026-11-14 18:47:20.486686+00
4	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	created	article	2551e3b0-66fc-4adf-bf5d-6a767dc9e952	{}	2026-11-14 18:48:27.787851+00
5	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	published	article	2551e3b0-66fc-4adf-bf5d-6a767dc9e952	{}	2026-11-14 18:48:28.115364+00
6	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	deleted	article	2551e3b0-66fc-4adf-bf5d-6a767dc9e952	{}	2026-11-14 19:13:07.347459+00
7	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	created	article	79f4a7ff-70ad-4361-a95d-b643ed4bd0e4	{}	2026-11-14 19:13:53.848138+00
8	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	published	article	79f4a7ff-70ad-4361-a95d-b643ed4bd0e4	{}	2026-11-14 19:13:54.191272+00
9	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	deleted	article	79f4a7ff-70ad-4361-a95d-b643ed4bd0e4	{}	2026-11-14 19:19:02.859496+00
10	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	created	article	c83d68ef-5488-4326-ad8d-0905a7f7d65b	{}	2026-11-14 19:46:24.10801+00
11	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	published	article	c83d68ef-5488-4326-ad8d-0905a7f7d65b	{}	2026-11-14 19:46:24.444779+00
12	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	deleted	article	c83d68ef-5488-4326-ad8d-0905a7f7d65b	{}	2026-11-14 19:54:32.416362+00
13	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	login	session	6d53a0e4-999f-44a3-92f2-f2601ce61050	{}	2026-11-16 12:10:48.796425+00
14	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	created	video	278f6839-b5a4-4a7a-aee0-fe0929ebc031	{}	2026-11-16 12:11:36.731035+00
15	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	published	video	278f6839-b5a4-4a7a-aee0-fe0929ebc031	{}	2026-11-16 12:11:41.771253+00
16	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	created	video	5d252348-2daf-4cc2-b883-1061f7ddff29	{}	2026-11-16 12:12:00.210362+00
17	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	published	video	5d252348-2daf-4cc2-b883-1061f7ddff29	{}	2026-11-16 12:12:03.427142+00
18	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	created	video	e654960a-c999-4a5c-a619-ce22d661b6c4	{}	2026-11-16 12:12:20.141498+00
19	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	published	video	e654960a-c999-4a5c-a619-ce22d661b6c4	{}	2026-11-16 12:12:23.255879+00
20	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	created	video	806b28d8-2629-439d-b58f-75cd90400848	{}	2026-11-16 12:13:18.4162+00
21	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	published	video	806b28d8-2629-439d-b58f-75cd90400848	{}	2026-11-16 12:13:22.100027+00
22	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	login	session	5cf74e91-df72-42d2-af2b-71356e3c4db4	{}	2026-11-22 07:43:48.520106+00
\.


--
-- Data for Name: admin_content_entries; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.admin_content_entries (id, module, title, content, target_url, image_url, placement, is_enabled, sort_order, created_by, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: admin_sessions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.admin_sessions (id, token_hash, csrf_hash, user_id, created_at, last_seen_at, expires_at) FROM stdin;
cbd58816-76b9-437c-9dad-db6f1578e23c	a6c976b3f968023a00d3ea9defc4800be80665d0c8bab082db987fef58f672c2	3e1a06b60fe07f4d16e67685b43e25884b524ceaf73125b29eb7adabbe23c97c	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-22 07:43:48.520106+00	2026-11-22 07:46:12.702022+00	2026-11-22 15:43:48.518+00
\.


--
-- Data for Name: article_placements; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.article_placements (article_id, placement, sort_order, created_at) FROM stdin;
\.


--
-- Data for Name: articles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.articles (id, slug, title, headline, summary, body, image_key, image_alt, category_id, status, author_id, published_at, created_at, updated_at, attribution, image_caption, image_credit) FROM stdin;
ef36937d-7f80-4d62-932c-ee88ce87a4dc	demo-content-stories-01	ডেমো: কনটেন্ট স্টোরি — নথি যাচাইয়ের প্রক্রিয়া (01)	নমুনা 1: কনটেন্ট স্টোরি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি কনটেন্ট স্টোরি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “কনটেন্ট স্টোরি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: নথি যাচাইয়ের প্রক্রিয়া। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-1.svg	পরীক্ষামূলক ছবি 1	72be7789-33f6-4293-919a-d8f58be84067	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
edc0e52c-824e-4dbc-80b2-1e0c283d6ca0	demo-content-stories-02	ডেমো: কনটেন্ট স্টোরি — সিদ্ধান্ত গ্রহণের সময়রেখা (02)	নমুনা 2: কনটেন্ট স্টোরি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি কনটেন্ট স্টোরি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “কনটেন্ট স্টোরি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: সিদ্ধান্ত গ্রহণের সময়রেখা। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-2.svg	পরীক্ষামূলক ছবি 2	72be7789-33f6-4293-919a-d8f58be84067	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 19:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
07c6bc51-259c-41fc-bcc4-44fde4fd0cd6	demo-content-stories-03	ডেমো: কনটেন্ট স্টোরি — জনস্বার্থে তথ্যের গুরুত্ব (03)	নমুনা 3: কনটেন্ট স্টোরি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি কনটেন্ট স্টোরি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “কনটেন্ট স্টোরি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: জনস্বার্থে তথ্যের গুরুত্ব। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-3.svg	পরীক্ষামূলক ছবি 3	72be7789-33f6-4293-919a-d8f58be84067	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 18:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
a6ccdd68-f500-4dd4-ab00-76c70dd5afe9	demo-content-stories-04	ডেমো: কনটেন্ট স্টোরি — জবাবদিহি নিশ্চিত করার উপায় (04)	নমুনা 4: কনটেন্ট স্টোরি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি কনটেন্ট স্টোরি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “কনটেন্ট স্টোরি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: জবাবদিহি নিশ্চিত করার উপায়। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-4.svg	পরীক্ষামূলক ছবি 4	72be7789-33f6-4293-919a-d8f58be84067	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 17:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
6dd7725c-d26f-4e6d-a580-f6d9bf2fa814	demo-content-stories-05	ডেমো: কনটেন্ট স্টোরি — স্থানীয় পর্যায়ে প্রভাবের চিত্র (05)	নমুনা 5: কনটেন্ট স্টোরি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি কনটেন্ট স্টোরি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “কনটেন্ট স্টোরি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: স্থানীয় পর্যায়ে প্রভাবের চিত্র। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-5.svg	পরীক্ষামূলক ছবি 5	72be7789-33f6-4293-919a-d8f58be84067	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 16:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
494d8602-e3d9-4f49-a75c-1921ea750de0	demo-content-stories-06	ডেমো: কনটেন্ট স্টোরি — তথ্য যাচাইয়ের ধাপ (06)	নমুনা 6: কনটেন্ট স্টোরি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি কনটেন্ট স্টোরি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “কনটেন্ট স্টোরি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: তথ্য যাচাইয়ের ধাপ। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-6.svg	পরীক্ষামূলক ছবি 6	72be7789-33f6-4293-919a-d8f58be84067	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 15:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
27a441f9-af0b-484e-b2d7-2679e20db4bd	demo-content-stories-07	ডেমো: কনটেন্ট স্টোরি — প্রশাসনিক প্রক্রিয়া বোঝার পাঠ (07)	নমুনা 7: কনটেন্ট স্টোরি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি কনটেন্ট স্টোরি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “কনটেন্ট স্টোরি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: প্রশাসনিক প্রক্রিয়া বোঝার পাঠ। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-7.svg	পরীক্ষামূলক ছবি 7	72be7789-33f6-4293-919a-d8f58be84067	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 14:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
c19e99a3-ca9c-4bfc-b375-f50d27b62570	demo-content-stories-08	ডেমো: কনটেন্ট স্টোরি — নাগরিক পর্যবেক্ষণের ভূমিকা (08)	নমুনা 8: কনটেন্ট স্টোরি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি কনটেন্ট স্টোরি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “কনটেন্ট স্টোরি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: নাগরিক পর্যবেক্ষণের ভূমিকা। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-8.svg	পরীক্ষামূলক ছবি 8	72be7789-33f6-4293-919a-d8f58be84067	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 13:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
c959be23-27db-44bf-8c62-395ff109d0ee	demo-content-stories-09	ডেমো: কনটেন্ট স্টোরি — প্রতিবেদন তৈরির পদ্ধতি (09)	নমুনা 9: কনটেন্ট স্টোরি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি কনটেন্ট স্টোরি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “কনটেন্ট স্টোরি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: প্রতিবেদন তৈরির পদ্ধতি। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-1.svg	পরীক্ষামূলক ছবি 1	72be7789-33f6-4293-919a-d8f58be84067	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 12:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
9daa3aac-0a39-4a78-a228-e82c3e17f2fd	demo-content-stories-10	ডেমো: কনটেন্ট স্টোরি — স্বচ্ছতা ও তথ্যপ্রাপ্তির প্রশ্ন (10)	নমুনা 10: কনটেন্ট স্টোরি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি কনটেন্ট স্টোরি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “কনটেন্ট স্টোরি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: স্বচ্ছতা ও তথ্যপ্রাপ্তির প্রশ্ন। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-2.svg	পরীক্ষামূলক ছবি 2	72be7789-33f6-4293-919a-d8f58be84067	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 11:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
cf750ab8-55dd-472a-ab94-379ead535e69	demo-power-and-influence-01	ডেমো: ক্ষমতা ও প্রভাব — নথি যাচাইয়ের প্রক্রিয়া (01)	নমুনা 1: ক্ষমতা ও প্রভাব বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি ক্ষমতা ও প্রভাব বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “ক্ষমতা ও প্রভাব” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: নথি যাচাইয়ের প্রক্রিয়া। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-2.svg	পরীক্ষামূলক ছবি 2	d5461122-e5e6-4e9d-b3d2-54931504023e	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 10:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
9a0b8006-98b6-4ddc-8288-cd4a781bc2a2	demo-power-and-influence-02	ডেমো: ক্ষমতা ও প্রভাব — সিদ্ধান্ত গ্রহণের সময়রেখা (02)	নমুনা 2: ক্ষমতা ও প্রভাব বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি ক্ষমতা ও প্রভাব বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “ক্ষমতা ও প্রভাব” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: সিদ্ধান্ত গ্রহণের সময়রেখা। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-3.svg	পরীক্ষামূলক ছবি 3	d5461122-e5e6-4e9d-b3d2-54931504023e	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 09:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
7c83a013-1e84-437b-8cc3-f4d59b788bad	demo-power-and-influence-03	ডেমো: ক্ষমতা ও প্রভাব — জনস্বার্থে তথ্যের গুরুত্ব (03)	নমুনা 3: ক্ষমতা ও প্রভাব বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি ক্ষমতা ও প্রভাব বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “ক্ষমতা ও প্রভাব” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: জনস্বার্থে তথ্যের গুরুত্ব। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-4.svg	পরীক্ষামূলক ছবি 4	d5461122-e5e6-4e9d-b3d2-54931504023e	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 08:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
064115fd-00a6-43bb-bb72-d6ebb858cdac	demo-power-and-influence-04	ডেমো: ক্ষমতা ও প্রভাব — জবাবদিহি নিশ্চিত করার উপায় (04)	নমুনা 4: ক্ষমতা ও প্রভাব বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি ক্ষমতা ও প্রভাব বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “ক্ষমতা ও প্রভাব” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: জবাবদিহি নিশ্চিত করার উপায়। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-5.svg	পরীক্ষামূলক ছবি 5	d5461122-e5e6-4e9d-b3d2-54931504023e	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 07:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
fa36612c-85b7-465d-ab79-36ee5fb9feff	demo-power-and-influence-05	ডেমো: ক্ষমতা ও প্রভাব — স্থানীয় পর্যায়ে প্রভাবের চিত্র (05)	নমুনা 5: ক্ষমতা ও প্রভাব বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি ক্ষমতা ও প্রভাব বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “ক্ষমতা ও প্রভাব” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: স্থানীয় পর্যায়ে প্রভাবের চিত্র। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-6.svg	পরীক্ষামূলক ছবি 6	d5461122-e5e6-4e9d-b3d2-54931504023e	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 06:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
ee04b655-4a3e-4d21-92c9-f9dd9c4a13b7	demo-power-and-influence-06	ডেমো: ক্ষমতা ও প্রভাব — তথ্য যাচাইয়ের ধাপ (06)	নমুনা 6: ক্ষমতা ও প্রভাব বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি ক্ষমতা ও প্রভাব বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “ক্ষমতা ও প্রভাব” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: তথ্য যাচাইয়ের ধাপ। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-7.svg	পরীক্ষামূলক ছবি 7	d5461122-e5e6-4e9d-b3d2-54931504023e	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 05:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
ff5e80f3-ae1a-48a7-90e9-c939c521db35	demo-power-and-influence-07	ডেমো: ক্ষমতা ও প্রভাব — প্রশাসনিক প্রক্রিয়া বোঝার পাঠ (07)	নমুনা 7: ক্ষমতা ও প্রভাব বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি ক্ষমতা ও প্রভাব বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “ক্ষমতা ও প্রভাব” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: প্রশাসনিক প্রক্রিয়া বোঝার পাঠ। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-8.svg	পরীক্ষামূলক ছবি 8	d5461122-e5e6-4e9d-b3d2-54931504023e	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 04:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
13bed995-aad0-40b7-be74-3f7423e9f85c	demo-power-and-influence-08	ডেমো: ক্ষমতা ও প্রভাব — নাগরিক পর্যবেক্ষণের ভূমিকা (08)	নমুনা 8: ক্ষমতা ও প্রভাব বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি ক্ষমতা ও প্রভাব বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “ক্ষমতা ও প্রভাব” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: নাগরিক পর্যবেক্ষণের ভূমিকা। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-1.svg	পরীক্ষামূলক ছবি 1	d5461122-e5e6-4e9d-b3d2-54931504023e	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 03:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
479bd86f-b08d-4a39-aff1-34e1661216b4	demo-power-and-influence-09	ডেমো: ক্ষমতা ও প্রভাব — প্রতিবেদন তৈরির পদ্ধতি (09)	নমুনা 9: ক্ষমতা ও প্রভাব বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি ক্ষমতা ও প্রভাব বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “ক্ষমতা ও প্রভাব” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: প্রতিবেদন তৈরির পদ্ধতি। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-2.svg	পরীক্ষামূলক ছবি 2	d5461122-e5e6-4e9d-b3d2-54931504023e	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 02:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
3ca42162-e3e9-4bf2-b793-76aefb134496	demo-power-and-influence-10	ডেমো: ক্ষমতা ও প্রভাব — স্বচ্ছতা ও তথ্যপ্রাপ্তির প্রশ্ন (10)	নমুনা 10: ক্ষমতা ও প্রভাব বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি ক্ষমতা ও প্রভাব বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “ক্ষমতা ও প্রভাব” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: স্বচ্ছতা ও তথ্যপ্রাপ্তির প্রশ্ন। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-3.svg	পরীক্ষামূলক ছবি 3	d5461122-e5e6-4e9d-b3d2-54931504023e	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 01:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
b0734190-b729-4315-b342-0eddfdcb6748	demo-corruption-01	ডেমো: দুর্নীতি — নথি যাচাইয়ের প্রক্রিয়া (01)	নমুনা 1: দুর্নীতি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি দুর্নীতি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “দুর্নীতি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: নথি যাচাইয়ের প্রক্রিয়া। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-3.svg	পরীক্ষামূলক ছবি 3	b4e99282-9f62-4b73-8946-74237bfe4dbb	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 00:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
57d60db4-ae16-4100-b87a-e60aed647fa1	demo-corruption-02	ডেমো: দুর্নীতি — সিদ্ধান্ত গ্রহণের সময়রেখা (02)	নমুনা 2: দুর্নীতি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি দুর্নীতি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “দুর্নীতি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: সিদ্ধান্ত গ্রহণের সময়রেখা। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-4.svg	পরীক্ষামূলক ছবি 4	b4e99282-9f62-4b73-8946-74237bfe4dbb	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 23:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
4fc88097-1c2c-4bfb-9182-a0e1fae0ed95	demo-corruption-03	ডেমো: দুর্নীতি — জনস্বার্থে তথ্যের গুরুত্ব (03)	নমুনা 3: দুর্নীতি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি দুর্নীতি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “দুর্নীতি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: জনস্বার্থে তথ্যের গুরুত্ব। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-5.svg	পরীক্ষামূলক ছবি 5	b4e99282-9f62-4b73-8946-74237bfe4dbb	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 22:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
704322c8-0721-4b12-84f5-1c35d62e50ab	demo-corruption-04	ডেমো: দুর্নীতি — জবাবদিহি নিশ্চিত করার উপায় (04)	নমুনা 4: দুর্নীতি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি দুর্নীতি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “দুর্নীতি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: জবাবদিহি নিশ্চিত করার উপায়। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-6.svg	পরীক্ষামূলক ছবি 6	b4e99282-9f62-4b73-8946-74237bfe4dbb	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 21:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
217f7280-f1db-4952-9a89-eee614e01cbe	demo-corruption-05	ডেমো: দুর্নীতি — স্থানীয় পর্যায়ে প্রভাবের চিত্র (05)	নমুনা 5: দুর্নীতি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি দুর্নীতি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “দুর্নীতি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: স্থানীয় পর্যায়ে প্রভাবের চিত্র। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-7.svg	পরীক্ষামূলক ছবি 7	b4e99282-9f62-4b73-8946-74237bfe4dbb	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 20:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
984403a4-0e49-4bf3-8251-ac0a54dada26	demo-corruption-06	ডেমো: দুর্নীতি — তথ্য যাচাইয়ের ধাপ (06)	নমুনা 6: দুর্নীতি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি দুর্নীতি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “দুর্নীতি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: তথ্য যাচাইয়ের ধাপ। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-8.svg	পরীক্ষামূলক ছবি 8	b4e99282-9f62-4b73-8946-74237bfe4dbb	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 19:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
9b5737f5-3f31-47a8-8bd6-8e6abc67dd74	demo-corruption-07	ডেমো: দুর্নীতি — প্রশাসনিক প্রক্রিয়া বোঝার পাঠ (07)	নমুনা 7: দুর্নীতি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি দুর্নীতি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “দুর্নীতি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: প্রশাসনিক প্রক্রিয়া বোঝার পাঠ। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-1.svg	পরীক্ষামূলক ছবি 1	b4e99282-9f62-4b73-8946-74237bfe4dbb	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 18:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
13ed64f1-8df2-4d49-ab9f-e0222f74d45d	demo-corruption-08	ডেমো: দুর্নীতি — নাগরিক পর্যবেক্ষণের ভূমিকা (08)	নমুনা 8: দুর্নীতি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি দুর্নীতি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “দুর্নীতি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: নাগরিক পর্যবেক্ষণের ভূমিকা। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-2.svg	পরীক্ষামূলক ছবি 2	b4e99282-9f62-4b73-8946-74237bfe4dbb	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 17:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
bb7279e1-f5bc-40e7-9309-69f824af06f5	demo-corruption-09	ডেমো: দুর্নীতি — প্রতিবেদন তৈরির পদ্ধতি (09)	নমুনা 9: দুর্নীতি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি দুর্নীতি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “দুর্নীতি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: প্রতিবেদন তৈরির পদ্ধতি। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-3.svg	পরীক্ষামূলক ছবি 3	b4e99282-9f62-4b73-8946-74237bfe4dbb	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 16:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
f2a67dac-ae9c-4f2d-a271-6b4d8fb0b659	demo-corruption-10	ডেমো: দুর্নীতি — স্বচ্ছতা ও তথ্যপ্রাপ্তির প্রশ্ন (10)	নমুনা 10: দুর্নীতি বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি দুর্নীতি বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “দুর্নীতি” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: স্বচ্ছতা ও তথ্যপ্রাপ্তির প্রশ্ন। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-4.svg	পরীক্ষামূলক ছবি 4	b4e99282-9f62-4b73-8946-74237bfe4dbb	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 15:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
c5d4240d-86ad-4b4c-84cb-9097ceddba6c	demo-opinion-01	ডেমো: মতামত — নথি যাচাইয়ের প্রক্রিয়া (01)	নমুনা 1: মতামত বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি মতামত বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “মতামত” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: নথি যাচাইয়ের প্রক্রিয়া। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-4.svg	পরীক্ষামূলক ছবি 4	7dfb37b5-49c1-4ea0-a629-805d749f2404	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 14:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
efa2769f-b5e3-4718-8988-923a92f517de	demo-opinion-02	ডেমো: মতামত — সিদ্ধান্ত গ্রহণের সময়রেখা (02)	নমুনা 2: মতামত বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি মতামত বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “মতামত” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: সিদ্ধান্ত গ্রহণের সময়রেখা। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-5.svg	পরীক্ষামূলক ছবি 5	7dfb37b5-49c1-4ea0-a629-805d749f2404	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 13:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
9dac21b0-ce88-4189-a3db-f33eb1d9849f	demo-opinion-03	ডেমো: মতামত — জনস্বার্থে তথ্যের গুরুত্ব (03)	নমুনা 3: মতামত বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি মতামত বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “মতামত” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: জনস্বার্থে তথ্যের গুরুত্ব। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-6.svg	পরীক্ষামূলক ছবি 6	7dfb37b5-49c1-4ea0-a629-805d749f2404	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 12:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
eee0b0df-d526-4bf8-9db0-f3d025a54c51	demo-opinion-04	ডেমো: মতামত — জবাবদিহি নিশ্চিত করার উপায় (04)	নমুনা 4: মতামত বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি মতামত বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “মতামত” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: জবাবদিহি নিশ্চিত করার উপায়। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-7.svg	পরীক্ষামূলক ছবি 7	7dfb37b5-49c1-4ea0-a629-805d749f2404	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 11:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
11e2adfe-a679-4fb7-b66b-da1b32492924	demo-opinion-05	ডেমো: মতামত — স্থানীয় পর্যায়ে প্রভাবের চিত্র (05)	নমুনা 5: মতামত বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি মতামত বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “মতামত” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: স্থানীয় পর্যায়ে প্রভাবের চিত্র। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-8.svg	পরীক্ষামূলক ছবি 8	7dfb37b5-49c1-4ea0-a629-805d749f2404	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 10:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
81b49b57-7e89-4e45-9594-752d4978295f	demo-opinion-06	ডেমো: মতামত — তথ্য যাচাইয়ের ধাপ (06)	নমুনা 6: মতামত বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি মতামত বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “মতামত” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: তথ্য যাচাইয়ের ধাপ। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-1.svg	পরীক্ষামূলক ছবি 1	7dfb37b5-49c1-4ea0-a629-805d749f2404	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 09:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
e784e542-79de-4489-be20-a51aa1dc77a9	demo-opinion-07	ডেমো: মতামত — প্রশাসনিক প্রক্রিয়া বোঝার পাঠ (07)	নমুনা 7: মতামত বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি মতামত বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “মতামত” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: প্রশাসনিক প্রক্রিয়া বোঝার পাঠ। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-2.svg	পরীক্ষামূলক ছবি 2	7dfb37b5-49c1-4ea0-a629-805d749f2404	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 08:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
f598e120-8efb-4c0b-a20f-a0a0639e81f9	demo-opinion-08	ডেমো: মতামত — নাগরিক পর্যবেক্ষণের ভূমিকা (08)	নমুনা 8: মতামত বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি মতামত বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “মতামত” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: নাগরিক পর্যবেক্ষণের ভূমিকা। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-3.svg	পরীক্ষামূলক ছবি 3	7dfb37b5-49c1-4ea0-a629-805d749f2404	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 07:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
12b2f051-567a-46da-a141-ba241d22fb6b	demo-opinion-09	ডেমো: মতামত — প্রতিবেদন তৈরির পদ্ধতি (09)	নমুনা 9: মতামত বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি মতামত বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “মতামত” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: প্রতিবেদন তৈরির পদ্ধতি। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-4.svg	পরীক্ষামূলক ছবি 4	7dfb37b5-49c1-4ea0-a629-805d749f2404	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 06:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
e68d28de-346f-4177-8f23-c980ad38d85a	demo-opinion-10	ডেমো: মতামত — স্বচ্ছতা ও তথ্যপ্রাপ্তির প্রশ্ন (10)	নমুনা 10: মতামত বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি মতামত বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “মতামত” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: স্বচ্ছতা ও তথ্যপ্রাপ্তির প্রশ্ন। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-5.svg	পরীক্ষামূলক ছবি 5	7dfb37b5-49c1-4ea0-a629-805d749f2404	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 05:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
a983d284-7564-4e7d-8f47-032edd65af26	demo-reports-01	ডেমো: রিপোর্ট — নথি যাচাইয়ের প্রক্রিয়া (01)	নমুনা 1: রিপোর্ট বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি রিপোর্ট বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “রিপোর্ট” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: নথি যাচাইয়ের প্রক্রিয়া। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-5.svg	পরীক্ষামূলক ছবি 5	89c99193-126f-426b-805d-c2e42abaf8c6	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 04:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
14cdcc69-fb68-44a4-a9ac-5be089e8d05d	demo-reports-02	ডেমো: রিপোর্ট — সিদ্ধান্ত গ্রহণের সময়রেখা (02)	নমুনা 2: রিপোর্ট বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি রিপোর্ট বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “রিপোর্ট” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: সিদ্ধান্ত গ্রহণের সময়রেখা। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-6.svg	পরীক্ষামূলক ছবি 6	89c99193-126f-426b-805d-c2e42abaf8c6	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 03:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
101605be-0cd5-46e8-9faa-624256b3fb37	demo-reports-03	ডেমো: রিপোর্ট — জনস্বার্থে তথ্যের গুরুত্ব (03)	নমুনা 3: রিপোর্ট বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি রিপোর্ট বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “রিপোর্ট” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: জনস্বার্থে তথ্যের গুরুত্ব। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-7.svg	পরীক্ষামূলক ছবি 7	89c99193-126f-426b-805d-c2e42abaf8c6	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 02:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
a7765c9d-1791-48ce-9fb7-9867edc1e546	demo-reports-04	ডেমো: রিপোর্ট — জবাবদিহি নিশ্চিত করার উপায় (04)	নমুনা 4: রিপোর্ট বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি রিপোর্ট বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “রিপোর্ট” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: জবাবদিহি নিশ্চিত করার উপায়। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-8.svg	পরীক্ষামূলক ছবি 8	89c99193-126f-426b-805d-c2e42abaf8c6	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 01:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
72bd92ca-6901-4f4f-8e9c-75818a3e8ac9	demo-reports-05	ডেমো: রিপোর্ট — স্থানীয় পর্যায়ে প্রভাবের চিত্র (05)	নমুনা 5: রিপোর্ট বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি রিপোর্ট বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “রিপোর্ট” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: স্থানীয় পর্যায়ে প্রভাবের চিত্র। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-1.svg	পরীক্ষামূলক ছবি 1	89c99193-126f-426b-805d-c2e42abaf8c6	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-13 00:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
f6a40370-9e43-4627-8bea-ded381a777b6	demo-reports-06	ডেমো: রিপোর্ট — তথ্য যাচাইয়ের ধাপ (06)	নমুনা 6: রিপোর্ট বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি রিপোর্ট বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “রিপোর্ট” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: তথ্য যাচাইয়ের ধাপ। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-2.svg	পরীক্ষামূলক ছবি 2	89c99193-126f-426b-805d-c2e42abaf8c6	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 23:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
72a6c6de-769d-473d-9064-68a16ec88273	demo-reports-07	ডেমো: রিপোর্ট — প্রশাসনিক প্রক্রিয়া বোঝার পাঠ (07)	নমুনা 7: রিপোর্ট বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি রিপোর্ট বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “রিপোর্ট” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: প্রশাসনিক প্রক্রিয়া বোঝার পাঠ। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-3.svg	পরীক্ষামূলক ছবি 3	89c99193-126f-426b-805d-c2e42abaf8c6	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 22:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
d7f8795c-c01c-4145-87a9-b7b2f6a56297	demo-reports-08	ডেমো: রিপোর্ট — নাগরিক পর্যবেক্ষণের ভূমিকা (08)	নমুনা 8: রিপোর্ট বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি রিপোর্ট বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “রিপোর্ট” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: নাগরিক পর্যবেক্ষণের ভূমিকা। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-4.svg	পরীক্ষামূলক ছবি 4	89c99193-126f-426b-805d-c2e42abaf8c6	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 21:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
dfa2309d-9b6c-4c25-84f6-6a2d9c4f4241	demo-reports-09	ডেমো: রিপোর্ট — প্রতিবেদন তৈরির পদ্ধতি (09)	নমুনা 9: রিপোর্ট বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি রিপোর্ট বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “রিপোর্ট” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: প্রতিবেদন তৈরির পদ্ধতি। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-5.svg	পরীক্ষামূলক ছবি 5	89c99193-126f-426b-805d-c2e42abaf8c6	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 20:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
1b81e018-36ab-4a3b-a4c3-b523cdc04f8b	demo-reports-10	ডেমো: রিপোর্ট — স্বচ্ছতা ও তথ্যপ্রাপ্তির প্রশ্ন (10)	নমুনা 10: রিপোর্ট বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি রিপোর্ট বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “রিপোর্ট” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: স্বচ্ছতা ও তথ্যপ্রাপ্তির প্রশ্ন। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-6.svg	পরীক্ষামূলক ছবি 6	89c99193-126f-426b-805d-c2e42abaf8c6	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 19:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
8b061377-1f49-480c-aba1-e696db1bda76	demo-organized-crime-01	ডেমো: সংঘটিত অপরাধ — নথি যাচাইয়ের প্রক্রিয়া (01)	নমুনা 1: সংঘটিত অপরাধ বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি সংঘটিত অপরাধ বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “সংঘটিত অপরাধ” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: নথি যাচাইয়ের প্রক্রিয়া। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-6.svg	পরীক্ষামূলক ছবি 6	e39074a8-b0b6-419a-b493-f6e8c69dec69	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 18:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
b7c880d5-bcdf-424a-9b3a-51a0ed15b989	demo-organized-crime-02	ডেমো: সংঘটিত অপরাধ — সিদ্ধান্ত গ্রহণের সময়রেখা (02)	নমুনা 2: সংঘটিত অপরাধ বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি সংঘটিত অপরাধ বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “সংঘটিত অপরাধ” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: সিদ্ধান্ত গ্রহণের সময়রেখা। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-7.svg	পরীক্ষামূলক ছবি 7	e39074a8-b0b6-419a-b493-f6e8c69dec69	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 17:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
7c71c980-c528-4274-8cfd-9fdc3b0b4a4c	demo-organized-crime-03	ডেমো: সংঘটিত অপরাধ — জনস্বার্থে তথ্যের গুরুত্ব (03)	নমুনা 3: সংঘটিত অপরাধ বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি সংঘটিত অপরাধ বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “সংঘটিত অপরাধ” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: জনস্বার্থে তথ্যের গুরুত্ব। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-8.svg	পরীক্ষামূলক ছবি 8	e39074a8-b0b6-419a-b493-f6e8c69dec69	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 16:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
24cc57a4-6c32-4b8b-bb90-2d09f32e12d6	demo-organized-crime-04	ডেমো: সংঘটিত অপরাধ — জবাবদিহি নিশ্চিত করার উপায় (04)	নমুনা 4: সংঘটিত অপরাধ বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি সংঘটিত অপরাধ বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “সংঘটিত অপরাধ” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: জবাবদিহি নিশ্চিত করার উপায়। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-1.svg	পরীক্ষামূলক ছবি 1	e39074a8-b0b6-419a-b493-f6e8c69dec69	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 15:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
c9553bdd-3b1f-4540-aba2-9f47509c8694	demo-organized-crime-05	ডেমো: সংঘটিত অপরাধ — স্থানীয় পর্যায়ে প্রভাবের চিত্র (05)	নমুনা 5: সংঘটিত অপরাধ বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি সংঘটিত অপরাধ বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “সংঘটিত অপরাধ” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: স্থানীয় পর্যায়ে প্রভাবের চিত্র। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-2.svg	পরীক্ষামূলক ছবি 2	e39074a8-b0b6-419a-b493-f6e8c69dec69	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 14:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
a823cbc5-4b23-46eb-9781-2d21a5c72bc9	demo-organized-crime-06	ডেমো: সংঘটিত অপরাধ — তথ্য যাচাইয়ের ধাপ (06)	নমুনা 6: সংঘটিত অপরাধ বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি সংঘটিত অপরাধ বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “সংঘটিত অপরাধ” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: তথ্য যাচাইয়ের ধাপ। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-3.svg	পরীক্ষামূলক ছবি 3	e39074a8-b0b6-419a-b493-f6e8c69dec69	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 13:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
407078de-7d71-45b5-8e6e-ad9c67d98334	demo-organized-crime-07	ডেমো: সংঘটিত অপরাধ — প্রশাসনিক প্রক্রিয়া বোঝার পাঠ (07)	নমুনা 7: সংঘটিত অপরাধ বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি সংঘটিত অপরাধ বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “সংঘটিত অপরাধ” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: প্রশাসনিক প্রক্রিয়া বোঝার পাঠ। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-4.svg	পরীক্ষামূলক ছবি 4	e39074a8-b0b6-419a-b493-f6e8c69dec69	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 12:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
5bfc51d0-d59b-43c8-8ed4-d6b5990fccbc	demo-organized-crime-08	ডেমো: সংঘটিত অপরাধ — নাগরিক পর্যবেক্ষণের ভূমিকা (08)	নমুনা 8: সংঘটিত অপরাধ বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি সংঘটিত অপরাধ বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “সংঘটিত অপরাধ” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: নাগরিক পর্যবেক্ষণের ভূমিকা। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-5.svg	পরীক্ষামূলক ছবি 5	e39074a8-b0b6-419a-b493-f6e8c69dec69	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 11:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
10ccaf80-91d2-4e87-96ac-1fd9e2be99b0	demo-organized-crime-09	ডেমো: সংঘটিত অপরাধ — প্রতিবেদন তৈরির পদ্ধতি (09)	নমুনা 9: সংঘটিত অপরাধ বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি সংঘটিত অপরাধ বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “সংঘটিত অপরাধ” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: প্রতিবেদন তৈরির পদ্ধতি। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-6.svg	পরীক্ষামূলক ছবি 6	e39074a8-b0b6-419a-b493-f6e8c69dec69	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 10:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
2db4a4e9-728c-4792-8a48-ff674c1c14d9	demo-organized-crime-10	ডেমো: সংঘটিত অপরাধ — স্বচ্ছতা ও তথ্যপ্রাপ্তির প্রশ্ন (10)	নমুনা 10: সংঘটিত অপরাধ বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি সংঘটিত অপরাধ বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “সংঘটিত অপরাধ” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: স্বচ্ছতা ও তথ্যপ্রাপ্তির প্রশ্ন। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-7.svg	পরীক্ষামূলক ছবি 7	e39074a8-b0b6-419a-b493-f6e8c69dec69	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 09:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
42b8f36e-d091-4409-830b-567cebde3f67	demo-freedom-and-repression-01	ডেমো: স্বাধীনতা ও দমন — নথি যাচাইয়ের প্রক্রিয়া (01)	নমুনা 1: স্বাধীনতা ও দমন বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি স্বাধীনতা ও দমন বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “স্বাধীনতা ও দমন” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: নথি যাচাইয়ের প্রক্রিয়া। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-7.svg	পরীক্ষামূলক ছবি 7	59300439-9b56-441c-bb38-5d346ce3566a	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 08:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
44d80878-ed56-48dc-9107-545fec211618	demo-freedom-and-repression-02	ডেমো: স্বাধীনতা ও দমন — সিদ্ধান্ত গ্রহণের সময়রেখা (02)	নমুনা 2: স্বাধীনতা ও দমন বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি স্বাধীনতা ও দমন বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “স্বাধীনতা ও দমন” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: সিদ্ধান্ত গ্রহণের সময়রেখা। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-8.svg	পরীক্ষামূলক ছবি 8	59300439-9b56-441c-bb38-5d346ce3566a	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 07:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
aa737185-3f1a-4d87-8b76-4e01ffc353e6	demo-freedom-and-repression-03	ডেমো: স্বাধীনতা ও দমন — জনস্বার্থে তথ্যের গুরুত্ব (03)	নমুনা 3: স্বাধীনতা ও দমন বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি স্বাধীনতা ও দমন বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “স্বাধীনতা ও দমন” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: জনস্বার্থে তথ্যের গুরুত্ব। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-1.svg	পরীক্ষামূলক ছবি 1	59300439-9b56-441c-bb38-5d346ce3566a	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 06:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
a1602786-8a10-466b-bae0-da47afcb7213	demo-freedom-and-repression-04	ডেমো: স্বাধীনতা ও দমন — জবাবদিহি নিশ্চিত করার উপায় (04)	নমুনা 4: স্বাধীনতা ও দমন বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি স্বাধীনতা ও দমন বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “স্বাধীনতা ও দমন” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: জবাবদিহি নিশ্চিত করার উপায়। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-2.svg	পরীক্ষামূলক ছবি 2	59300439-9b56-441c-bb38-5d346ce3566a	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 05:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
d3854efc-1f5c-4f4b-bca5-809f1d001f99	demo-freedom-and-repression-05	ডেমো: স্বাধীনতা ও দমন — স্থানীয় পর্যায়ে প্রভাবের চিত্র (05)	নমুনা 5: স্বাধীনতা ও দমন বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি স্বাধীনতা ও দমন বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “স্বাধীনতা ও দমন” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: স্থানীয় পর্যায়ে প্রভাবের চিত্র। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-3.svg	পরীক্ষামূলক ছবি 3	59300439-9b56-441c-bb38-5d346ce3566a	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 04:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
331919fc-b17e-4a2c-b40e-6b2fe3d998a0	demo-freedom-and-repression-06	ডেমো: স্বাধীনতা ও দমন — তথ্য যাচাইয়ের ধাপ (06)	নমুনা 6: স্বাধীনতা ও দমন বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি স্বাধীনতা ও দমন বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “স্বাধীনতা ও দমন” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: তথ্য যাচাইয়ের ধাপ। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-4.svg	পরীক্ষামূলক ছবি 4	59300439-9b56-441c-bb38-5d346ce3566a	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 03:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
79e9a575-f5bc-4015-b173-60f7990de1af	demo-freedom-and-repression-07	ডেমো: স্বাধীনতা ও দমন — প্রশাসনিক প্রক্রিয়া বোঝার পাঠ (07)	নমুনা 7: স্বাধীনতা ও দমন বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি স্বাধীনতা ও দমন বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “স্বাধীনতা ও দমন” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: প্রশাসনিক প্রক্রিয়া বোঝার পাঠ। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-5.svg	পরীক্ষামূলক ছবি 5	59300439-9b56-441c-bb38-5d346ce3566a	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 02:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
e59d33ef-6a66-464a-8b4e-b44f4ab1cddf	demo-freedom-and-repression-08	ডেমো: স্বাধীনতা ও দমন — নাগরিক পর্যবেক্ষণের ভূমিকা (08)	নমুনা 8: স্বাধীনতা ও দমন বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি স্বাধীনতা ও দমন বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “স্বাধীনতা ও দমন” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: নাগরিক পর্যবেক্ষণের ভূমিকা। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-6.svg	পরীক্ষামূলক ছবি 6	59300439-9b56-441c-bb38-5d346ce3566a	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 01:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
a699e596-481a-4767-9b44-cfb183180ffd	demo-freedom-and-repression-09	ডেমো: স্বাধীনতা ও দমন — প্রতিবেদন তৈরির পদ্ধতি (09)	নমুনা 9: স্বাধীনতা ও দমন বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি স্বাধীনতা ও দমন বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “স্বাধীনতা ও দমন” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: প্রতিবেদন তৈরির পদ্ধতি। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-7.svg	পরীক্ষামূলক ছবি 7	59300439-9b56-441c-bb38-5d346ce3566a	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-12 00:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
a908eb74-8fec-4396-b8de-516cd4bbb5ac	demo-freedom-and-repression-10	ডেমো: স্বাধীনতা ও দমন — স্বচ্ছতা ও তথ্যপ্রাপ্তির প্রশ্ন (10)	নমুনা 10: স্বাধীনতা ও দমন বিষয়ে পরীক্ষামূলক প্রতিবেদন	এটি স্বাধীনতা ও দমন বিভাগের জন্য তৈরি একটি পরীক্ষামূলক নমুনা প্রতিবেদন। ওয়েবসাইটের লেআউট, ছবি, বিভাগ ও নিবন্ধের পাতা পরীক্ষা করার জন্য কনটেন্টটি ব্যবহার করা হয়েছে; এটি বাস্তব সংবাদ নয়।	<p>এটি অনুসন্ধান ওয়েবসাইটের পরীক্ষামূলক কনটেন্ট। “স্বাধীনতা ও দমন” বিভাগের নিবন্ধের বিন্যাস, শিরোনাম, সারাংশ এবং ছবি কীভাবে দেখা যায় তা যাচাই করার জন্য এই নমুনা তৈরি করা হয়েছে।</p>\\n\\n<p>এই নমুনা প্রতিবেদনের বিষয়: স্বচ্ছতা ও তথ্যপ্রাপ্তির প্রশ্ন। এখানে কোনো বাস্তব ঘটনা, ব্যক্তি, প্রতিষ্ঠান বা অভিযোগের তথ্য দেওয়া হচ্ছে না। প্রকাশের আগে প্রকৃত প্রতিবেদনের তথ্য, নথি, বক্তব্য এবং প্রাসঙ্গিক সূত্র যুক্ত করতে হবে।</p>\\n\\n<p>পরীক্ষার সময় এই পাতায় শিরোনাম, মূল লেখা, প্রকাশের সময়, বিভাগ এবং সংযুক্ত ছবির প্রদর্শন যাচাই করুন। কাজ শেষ হলে npm run seed:remove-test-articles চালিয়ে সব পরীক্ষামূলক নিবন্ধ সরিয়ে ফেলা যাবে।</p>	test-seed/onushandhan/v1/article-8.svg	পরীক্ষামূলক ছবি 8	59300439-9b56-441c-bb38-5d346ce3566a	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-11 23:07:20.957164+00	2026-11-14 20:07:20.957164+00	2026-11-14 20:07:20.957164+00			
\.


--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.categories (id, name, slug, parent_id, is_enabled, created_at, updated_at, nav_sort_order, homepage_sort_order, homepage_layout) FROM stdin;
72be7789-33f6-4293-919a-d8f58be84067	কনটেন্ট স্টোরি	content-stories	\N	t	2026-11-14 17:49:31.9963+00	2026-11-14 17:49:31.9963+00	0	0	lead-headlines
d5461122-e5e6-4e9d-b3d2-54931504023e	ক্ষমতা ও প্রভাব	power-and-influence	\N	t	2026-11-14 17:49:31.9963+00	2026-11-14 17:49:31.9963+00	1	1	feature-headlines
b4e99282-9f62-4b73-8946-74237bfe4dbb	দুর্নীতি	corruption	\N	t	2026-11-14 17:49:31.9963+00	2026-11-14 17:49:31.9963+00	2	2	image-grid
0cff0cd2-8988-4bda-98d9-1b93e115e43c	ভিডিও পডকাস্ট	video-podcast	\N	t	2026-11-14 17:49:31.9963+00	2026-11-14 17:49:31.9963+00	3	3	headline-list
7dfb37b5-49c1-4ea0-a629-805d749f2404	মতামত	opinion	\N	t	2026-11-14 17:49:31.9963+00	2026-11-14 17:49:31.9963+00	4	4	feature-headlines
89c99193-126f-426b-805d-c2e42abaf8c6	রিপোর্ট	reports	\N	t	2026-11-14 17:49:31.9963+00	2026-11-14 17:49:31.9963+00	5	5	lead-headlines
59300439-9b56-441c-bb38-5d346ce3566a	স্বাধীনতা ও দমন	freedom-and-repression	\N	t	2026-11-14 17:49:31.9963+00	2026-11-14 17:49:31.9963+00	7	7	image-grid
e39074a8-b0b6-419a-b493-f6e8c69dec69	সংঘটিত অপরাধ	organized-crime	\N	t	2026-11-14 17:49:31.9963+00	2026-11-14 17:49:31.9963+00	6	6	image-grid
\.


--
-- Data for Name: media_assets; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.media_assets (id, object_key, media_type, content_type, size_bytes, status, uploader_id, created_at) FROM stdin;
eb97025c-dcd9-47cf-aeb4-84963cd71ea8	uploads/5e8e168d-0dcb-476c-81f0-bc7cd88d4156/359d8a98-432d-4444-bc03-3d685cb3a948.png	image	image/png	25530	uploading	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 18:48:06.769622+00
d8c7c859-19a2-43ca-acec-d3cd7cfe66cc	uploads/5e8e168d-0dcb-476c-81f0-bc7cd88d4156/ca24b16c-6949-4e65-923f-2fce352c269c.png	image	image/png	25530	uploading	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 19:13:43.049142+00
bfcee710-3d35-4d96-8426-67a6ebb3f3d1	uploads/5e8e168d-0dcb-476c-81f0-bc7cd88d4156/34aa7dfa-464a-45dd-b577-9f2e3ef5893a.jpg	image	image/jpeg	178360	uploading	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 19:18:42.455061+00
233dec4a-201f-4616-9ba2-2e58398ee022	uploads/5e8e168d-0dcb-476c-81f0-bc7cd88d4156/0cea08c7-4923-4429-8044-2edcaf76ffb6.jpg	image	image/jpeg	552450	uploading	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 19:18:54.299754+00
1fd59a3e-106d-47d4-a16c-2173f21e5b04	uploads/5e8e168d-0dcb-476c-81f0-bc7cd88d4156/47ab3924-1fbb-4e97-911d-c4eaf920e094.jpg	image	image/jpeg	552450	uploading	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 19:19:08.640224+00
49116cae-23fc-400c-b811-c4394617ec91	uploads/5e8e168d-0dcb-476c-81f0-bc7cd88d4156/0937fb2d-502e-4fdf-b9ae-e98a13aa2d04.jpg	image	image/jpeg	178360	uploading	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 19:19:19.14749+00
5ec1e864-c954-42bc-aeae-1a84f58d018d	uploads/5e8e168d-0dcb-476c-81f0-bc7cd88d4156/f8d4f422-c085-410c-85c8-c7af00fb8918.png	image	image/png	964486	uploading	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 19:22:26.841305+00
39e9f3fb-24b3-43a5-978b-baafa7baa891	uploads/5e8e168d-0dcb-476c-81f0-bc7cd88d4156/5d2762d7-0cf3-4b32-b3a8-2ecc89c37972.jpg	image	image/jpeg	178360	uploading	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 19:22:48.48462+00
dbadc659-737c-4d72-9a2c-b6c7c1b4d063	uploads/5e8e168d-0dcb-476c-81f0-bc7cd88d4156/0332fed4-40ed-41ac-b3cd-b5b994569871.jpg	image	image/jpeg	552450	uploading	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 19:23:00.384171+00
dfa50ecf-efd9-4c7e-981c-8cc2a71dfef6	uploads/5e8e168d-0dcb-476c-81f0-bc7cd88d4156/160e90ba-3d40-4699-b384-f5813ef9abe6.png	image	image/png	964486	uploading	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 19:23:25.951697+00
2b535dca-4b1a-4bcd-9b47-6ca780d77d85	uploads/5e8e168d-0dcb-476c-81f0-bc7cd88d4156/cbdf6d50-4f73-4bda-ae29-04a89d6d99e4.png	image	image/png	964486	uploading	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 19:23:50.190443+00
f228a1f3-5dcb-490a-b75c-5ccec7e0929c	uploads/5e8e168d-0dcb-476c-81f0-bc7cd88d4156/d518e971-541f-45ca-890d-f11953b54595.jpg	image	image/jpeg	552450	uploading	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 19:26:50.413791+00
ea941c9d-b6af-4850-b46e-9943a36fe150	uploads/5e8e168d-0dcb-476c-81f0-bc7cd88d4156/67a9898a-be30-43f8-ad8e-78c242279827.png	image	image/png	964486	uploading	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 19:28:39.881111+00
8e5ac20e-e3bb-4114-b65e-ea1feb7d60ef	uploads/5e8e168d-0dcb-476c-81f0-bc7cd88d4156/672abd25-e408-4660-8bcd-df845bb7dd37.png	image	image/png	964486	uploading	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 19:38:09.589675+00
a767896d-1d80-49ff-8cdb-97797218aff2	uploads/5e8e168d-0dcb-476c-81f0-bc7cd88d4156/b5b436b0-6899-4bf4-b792-a706a55343e9.png	image	image/png	964486	uploading	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 19:38:19.530597+00
4e8dd860-5f78-42b7-ae39-56cecb807318	uploads/5e8e168d-0dcb-476c-81f0-bc7cd88d4156/2f5cc886-ff62-4944-a840-561432563db3.png	image	image/png	964486	uploading	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 19:39:07.295091+00
e74e9626-2641-4fc0-971a-995c38fc9aac	uploads/5e8e168d-0dcb-476c-81f0-bc7cd88d4156/a676eff1-ddfe-4d6c-bdbd-d94e5cb8cec3.png	image	image/png	964486	uploading	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 19:39:21.503089+00
bef45597-668f-4cdb-8139-1ada8937e41c	uploads/5e8e168d-0dcb-476c-81f0-bc7cd88d4156/522e2aef-1f3a-441e-bd7e-94df2668649d.png	image	image/png	964486	ready	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 19:46:07.905366+00
1bc77959-d0a9-47d8-bb14-6cd66a35d550	test-seed/onushandhan/v1/article-1.svg	image	image/svg+xml	651	ready	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 20:07:20.957164+00
6ea71278-eade-4005-acc4-c6aa10f4ec4b	test-seed/onushandhan/v1/article-2.svg	image	image/svg+xml	643	ready	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 20:07:20.957164+00
fd3e75e5-8dc7-4d6e-868a-423c467e6905	test-seed/onushandhan/v1/article-3.svg	image	image/svg+xml	681	ready	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 20:07:20.957164+00
6dd4bf6f-9b7f-4e1d-8145-d13b8efffe01	test-seed/onushandhan/v1/article-4.svg	image	image/svg+xml	706	ready	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 20:07:20.957164+00
b33133d9-425a-48d5-8eee-ed817bece8ff	test-seed/onushandhan/v1/article-5.svg	image	image/svg+xml	754	ready	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 20:07:20.957164+00
c1d397ea-2961-4da8-9889-3cc219aa3e05	test-seed/onushandhan/v1/article-6.svg	image	image/svg+xml	683	ready	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 20:07:20.957164+00
860e44e9-fc0c-4a82-8c61-31d9f3188821	test-seed/onushandhan/v1/article-7.svg	image	image/svg+xml	746	ready	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 20:07:20.957164+00
12ec911e-e9a9-4e71-8410-792d288f38d8	test-seed/onushandhan/v1/article-8.svg	image	image/svg+xml	685	ready	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-14 20:07:20.957164+00
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.schema_migrations (filename, applied_at) FROM stdin;
001_initial.sql	2026-11-14 17:49:31.9963+00
002_add_instagram_site_setting.sql	2026-11-14 17:49:31.9963+00
003_category_layout_and_order.sql	2026-11-14 17:49:31.9963+00
004_video_only_category.sql	2026-11-14 17:49:31.9963+00
005_test_article_seeder.sql	2026-11-14 20:03:00.586226+00
006_article_editor_fields.sql	2026-11-22 07:45:38.621995+00
007_admin_modules_and_maintenance.sql	2026-11-22 08:13:55.872822+00
008_user_avatar.sql	2026-11-22 08:13:55.872822+00
\.


--
-- Data for Name: section_articles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.section_articles (section_id, article_id, sort_order) FROM stdin;
\.


--
-- Data for Name: site_sections; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.site_sections (id, slug, title, description, is_enabled, sort_order, updated_at) FROM stdin;
b9681832-a063-4199-ab4a-732003d6cff8	featured	প্রচ্ছদ প্রতিবেদন		t	1	2026-11-14 17:49:31.9963+00
2188f6a2-8c8f-4cad-ab4f-90322e18ef44	latest	সর্বশেষ সংবাদ		t	2	2026-11-14 17:49:31.9963+00
\.


--
-- Data for Name: site_settings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.site_settings (setting_key, setting_value, updated_at) FROM stdin;
site_name	অনুসন্ধান	2026-11-14 17:49:31.9963+00
contact_email	news@onusondhan24.com	2026-11-14 17:49:31.9963+00
facebook_url	https://www.facebook.com/	2026-11-14 17:49:31.9963+00
youtube_url	https://www.youtube.com/	2026-11-14 17:49:31.9963+00
instagram_url		2026-11-14 17:49:31.9963+00
maintenance_mode	false	2026-11-22 08:13:55.872822+00
\.


--
-- Data for Name: test_seed_articles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.test_seed_articles (article_id, category_id, seed_version, created_at) FROM stdin;
ef36937d-7f80-4d62-932c-ee88ce87a4dc	72be7789-33f6-4293-919a-d8f58be84067	v1	2026-11-14 20:07:20.957164+00
edc0e52c-824e-4dbc-80b2-1e0c283d6ca0	72be7789-33f6-4293-919a-d8f58be84067	v1	2026-11-14 20:07:20.957164+00
07c6bc51-259c-41fc-bcc4-44fde4fd0cd6	72be7789-33f6-4293-919a-d8f58be84067	v1	2026-11-14 20:07:20.957164+00
a6ccdd68-f500-4dd4-ab00-76c70dd5afe9	72be7789-33f6-4293-919a-d8f58be84067	v1	2026-11-14 20:07:20.957164+00
6dd7725c-d26f-4e6d-a580-f6d9bf2fa814	72be7789-33f6-4293-919a-d8f58be84067	v1	2026-11-14 20:07:20.957164+00
494d8602-e3d9-4f49-a75c-1921ea750de0	72be7789-33f6-4293-919a-d8f58be84067	v1	2026-11-14 20:07:20.957164+00
27a441f9-af0b-484e-b2d7-2679e20db4bd	72be7789-33f6-4293-919a-d8f58be84067	v1	2026-11-14 20:07:20.957164+00
c19e99a3-ca9c-4bfc-b375-f50d27b62570	72be7789-33f6-4293-919a-d8f58be84067	v1	2026-11-14 20:07:20.957164+00
c959be23-27db-44bf-8c62-395ff109d0ee	72be7789-33f6-4293-919a-d8f58be84067	v1	2026-11-14 20:07:20.957164+00
9daa3aac-0a39-4a78-a228-e82c3e17f2fd	72be7789-33f6-4293-919a-d8f58be84067	v1	2026-11-14 20:07:20.957164+00
cf750ab8-55dd-472a-ab94-379ead535e69	d5461122-e5e6-4e9d-b3d2-54931504023e	v1	2026-11-14 20:07:20.957164+00
9a0b8006-98b6-4ddc-8288-cd4a781bc2a2	d5461122-e5e6-4e9d-b3d2-54931504023e	v1	2026-11-14 20:07:20.957164+00
7c83a013-1e84-437b-8cc3-f4d59b788bad	d5461122-e5e6-4e9d-b3d2-54931504023e	v1	2026-11-14 20:07:20.957164+00
064115fd-00a6-43bb-bb72-d6ebb858cdac	d5461122-e5e6-4e9d-b3d2-54931504023e	v1	2026-11-14 20:07:20.957164+00
fa36612c-85b7-465d-ab79-36ee5fb9feff	d5461122-e5e6-4e9d-b3d2-54931504023e	v1	2026-11-14 20:07:20.957164+00
ee04b655-4a3e-4d21-92c9-f9dd9c4a13b7	d5461122-e5e6-4e9d-b3d2-54931504023e	v1	2026-11-14 20:07:20.957164+00
ff5e80f3-ae1a-48a7-90e9-c939c521db35	d5461122-e5e6-4e9d-b3d2-54931504023e	v1	2026-11-14 20:07:20.957164+00
13bed995-aad0-40b7-be74-3f7423e9f85c	d5461122-e5e6-4e9d-b3d2-54931504023e	v1	2026-11-14 20:07:20.957164+00
479bd86f-b08d-4a39-aff1-34e1661216b4	d5461122-e5e6-4e9d-b3d2-54931504023e	v1	2026-11-14 20:07:20.957164+00
3ca42162-e3e9-4bf2-b793-76aefb134496	d5461122-e5e6-4e9d-b3d2-54931504023e	v1	2026-11-14 20:07:20.957164+00
b0734190-b729-4315-b342-0eddfdcb6748	b4e99282-9f62-4b73-8946-74237bfe4dbb	v1	2026-11-14 20:07:20.957164+00
57d60db4-ae16-4100-b87a-e60aed647fa1	b4e99282-9f62-4b73-8946-74237bfe4dbb	v1	2026-11-14 20:07:20.957164+00
4fc88097-1c2c-4bfb-9182-a0e1fae0ed95	b4e99282-9f62-4b73-8946-74237bfe4dbb	v1	2026-11-14 20:07:20.957164+00
704322c8-0721-4b12-84f5-1c35d62e50ab	b4e99282-9f62-4b73-8946-74237bfe4dbb	v1	2026-11-14 20:07:20.957164+00
217f7280-f1db-4952-9a89-eee614e01cbe	b4e99282-9f62-4b73-8946-74237bfe4dbb	v1	2026-11-14 20:07:20.957164+00
984403a4-0e49-4bf3-8251-ac0a54dada26	b4e99282-9f62-4b73-8946-74237bfe4dbb	v1	2026-11-14 20:07:20.957164+00
9b5737f5-3f31-47a8-8bd6-8e6abc67dd74	b4e99282-9f62-4b73-8946-74237bfe4dbb	v1	2026-11-14 20:07:20.957164+00
13ed64f1-8df2-4d49-ab9f-e0222f74d45d	b4e99282-9f62-4b73-8946-74237bfe4dbb	v1	2026-11-14 20:07:20.957164+00
bb7279e1-f5bc-40e7-9309-69f824af06f5	b4e99282-9f62-4b73-8946-74237bfe4dbb	v1	2026-11-14 20:07:20.957164+00
f2a67dac-ae9c-4f2d-a271-6b4d8fb0b659	b4e99282-9f62-4b73-8946-74237bfe4dbb	v1	2026-11-14 20:07:20.957164+00
c5d4240d-86ad-4b4c-84cb-9097ceddba6c	7dfb37b5-49c1-4ea0-a629-805d749f2404	v1	2026-11-14 20:07:20.957164+00
efa2769f-b5e3-4718-8988-923a92f517de	7dfb37b5-49c1-4ea0-a629-805d749f2404	v1	2026-11-14 20:07:20.957164+00
9dac21b0-ce88-4189-a3db-f33eb1d9849f	7dfb37b5-49c1-4ea0-a629-805d749f2404	v1	2026-11-14 20:07:20.957164+00
eee0b0df-d526-4bf8-9db0-f3d025a54c51	7dfb37b5-49c1-4ea0-a629-805d749f2404	v1	2026-11-14 20:07:20.957164+00
11e2adfe-a679-4fb7-b66b-da1b32492924	7dfb37b5-49c1-4ea0-a629-805d749f2404	v1	2026-11-14 20:07:20.957164+00
81b49b57-7e89-4e45-9594-752d4978295f	7dfb37b5-49c1-4ea0-a629-805d749f2404	v1	2026-11-14 20:07:20.957164+00
e784e542-79de-4489-be20-a51aa1dc77a9	7dfb37b5-49c1-4ea0-a629-805d749f2404	v1	2026-11-14 20:07:20.957164+00
f598e120-8efb-4c0b-a20f-a0a0639e81f9	7dfb37b5-49c1-4ea0-a629-805d749f2404	v1	2026-11-14 20:07:20.957164+00
12b2f051-567a-46da-a141-ba241d22fb6b	7dfb37b5-49c1-4ea0-a629-805d749f2404	v1	2026-11-14 20:07:20.957164+00
e68d28de-346f-4177-8f23-c980ad38d85a	7dfb37b5-49c1-4ea0-a629-805d749f2404	v1	2026-11-14 20:07:20.957164+00
a983d284-7564-4e7d-8f47-032edd65af26	89c99193-126f-426b-805d-c2e42abaf8c6	v1	2026-11-14 20:07:20.957164+00
14cdcc69-fb68-44a4-a9ac-5be089e8d05d	89c99193-126f-426b-805d-c2e42abaf8c6	v1	2026-11-14 20:07:20.957164+00
101605be-0cd5-46e8-9faa-624256b3fb37	89c99193-126f-426b-805d-c2e42abaf8c6	v1	2026-11-14 20:07:20.957164+00
a7765c9d-1791-48ce-9fb7-9867edc1e546	89c99193-126f-426b-805d-c2e42abaf8c6	v1	2026-11-14 20:07:20.957164+00
72bd92ca-6901-4f4f-8e9c-75818a3e8ac9	89c99193-126f-426b-805d-c2e42abaf8c6	v1	2026-11-14 20:07:20.957164+00
f6a40370-9e43-4627-8bea-ded381a777b6	89c99193-126f-426b-805d-c2e42abaf8c6	v1	2026-11-14 20:07:20.957164+00
72a6c6de-769d-473d-9064-68a16ec88273	89c99193-126f-426b-805d-c2e42abaf8c6	v1	2026-11-14 20:07:20.957164+00
d7f8795c-c01c-4145-87a9-b7b2f6a56297	89c99193-126f-426b-805d-c2e42abaf8c6	v1	2026-11-14 20:07:20.957164+00
dfa2309d-9b6c-4c25-84f6-6a2d9c4f4241	89c99193-126f-426b-805d-c2e42abaf8c6	v1	2026-11-14 20:07:20.957164+00
1b81e018-36ab-4a3b-a4c3-b523cdc04f8b	89c99193-126f-426b-805d-c2e42abaf8c6	v1	2026-11-14 20:07:20.957164+00
8b061377-1f49-480c-aba1-e696db1bda76	e39074a8-b0b6-419a-b493-f6e8c69dec69	v1	2026-11-14 20:07:20.957164+00
b7c880d5-bcdf-424a-9b3a-51a0ed15b989	e39074a8-b0b6-419a-b493-f6e8c69dec69	v1	2026-11-14 20:07:20.957164+00
7c71c980-c528-4274-8cfd-9fdc3b0b4a4c	e39074a8-b0b6-419a-b493-f6e8c69dec69	v1	2026-11-14 20:07:20.957164+00
24cc57a4-6c32-4b8b-bb90-2d09f32e12d6	e39074a8-b0b6-419a-b493-f6e8c69dec69	v1	2026-11-14 20:07:20.957164+00
c9553bdd-3b1f-4540-aba2-9f47509c8694	e39074a8-b0b6-419a-b493-f6e8c69dec69	v1	2026-11-14 20:07:20.957164+00
a823cbc5-4b23-46eb-9781-2d21a5c72bc9	e39074a8-b0b6-419a-b493-f6e8c69dec69	v1	2026-11-14 20:07:20.957164+00
407078de-7d71-45b5-8e6e-ad9c67d98334	e39074a8-b0b6-419a-b493-f6e8c69dec69	v1	2026-11-14 20:07:20.957164+00
5bfc51d0-d59b-43c8-8ed4-d6b5990fccbc	e39074a8-b0b6-419a-b493-f6e8c69dec69	v1	2026-11-14 20:07:20.957164+00
10ccaf80-91d2-4e87-96ac-1fd9e2be99b0	e39074a8-b0b6-419a-b493-f6e8c69dec69	v1	2026-11-14 20:07:20.957164+00
2db4a4e9-728c-4792-8a48-ff674c1c14d9	e39074a8-b0b6-419a-b493-f6e8c69dec69	v1	2026-11-14 20:07:20.957164+00
42b8f36e-d091-4409-830b-567cebde3f67	59300439-9b56-441c-bb38-5d346ce3566a	v1	2026-11-14 20:07:20.957164+00
44d80878-ed56-48dc-9107-545fec211618	59300439-9b56-441c-bb38-5d346ce3566a	v1	2026-11-14 20:07:20.957164+00
aa737185-3f1a-4d87-8b76-4e01ffc353e6	59300439-9b56-441c-bb38-5d346ce3566a	v1	2026-11-14 20:07:20.957164+00
a1602786-8a10-466b-bae0-da47afcb7213	59300439-9b56-441c-bb38-5d346ce3566a	v1	2026-11-14 20:07:20.957164+00
d3854efc-1f5c-4f4b-bca5-809f1d001f99	59300439-9b56-441c-bb38-5d346ce3566a	v1	2026-11-14 20:07:20.957164+00
331919fc-b17e-4a2c-b40e-6b2fe3d998a0	59300439-9b56-441c-bb38-5d346ce3566a	v1	2026-11-14 20:07:20.957164+00
79e9a575-f5bc-4015-b173-60f7990de1af	59300439-9b56-441c-bb38-5d346ce3566a	v1	2026-11-14 20:07:20.957164+00
e59d33ef-6a66-464a-8b4e-b44f4ab1cddf	59300439-9b56-441c-bb38-5d346ce3566a	v1	2026-11-14 20:07:20.957164+00
a699e596-481a-4767-9b44-cfb183180ffd	59300439-9b56-441c-bb38-5d346ce3566a	v1	2026-11-14 20:07:20.957164+00
a908eb74-8fec-4396-b8de-516cd4bbb5ac	59300439-9b56-441c-bb38-5d346ce3566a	v1	2026-11-14 20:07:20.957164+00
\.


--
-- Data for Name: test_seed_assets; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.test_seed_assets (id, object_key, media_asset_id, created_at) FROM stdin;
0716c72f-2556-4573-8b68-99e85ef2f3af	test-seed/onushandhan/v1/article-1.svg	1bc77959-d0a9-47d8-bb14-6cd66a35d550	2026-11-14 20:07:20.957164+00
50849dba-3f70-4791-85cf-62d87ba6fb75	test-seed/onushandhan/v1/article-2.svg	6ea71278-eade-4005-acc4-c6aa10f4ec4b	2026-11-14 20:07:20.957164+00
50715c0d-c560-46fc-b183-6f0605d94609	test-seed/onushandhan/v1/article-3.svg	fd3e75e5-8dc7-4d6e-868a-423c467e6905	2026-11-14 20:07:20.957164+00
c3cb1926-3290-40c3-a40c-1cb641074807	test-seed/onushandhan/v1/article-4.svg	6dd4bf6f-9b7f-4e1d-8145-d13b8efffe01	2026-11-14 20:07:20.957164+00
dcc940fb-d640-401b-b911-ca55ff7e4b1d	test-seed/onushandhan/v1/article-5.svg	b33133d9-425a-48d5-8eee-ed817bece8ff	2026-11-14 20:07:20.957164+00
8af7f072-8147-4770-9eab-94ea81c1bed8	test-seed/onushandhan/v1/article-6.svg	c1d397ea-2961-4da8-9889-3cc219aa3e05	2026-11-14 20:07:20.957164+00
05f03127-0429-4495-8f1e-cf3e65e055ed	test-seed/onushandhan/v1/article-7.svg	860e44e9-fc0c-4a82-8c61-31d9f3188821	2026-11-14 20:07:20.957164+00
7c81e588-633b-4049-a950-866332dba1b6	test-seed/onushandhan/v1/article-8.svg	12ec911e-e9a9-4e71-8410-792d288f38d8	2026-11-14 20:07:20.957164+00
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (id, username, email, password_hash, role, status, created_at, updated_at, last_login_at, avatar_url) FROM stdin;
5e8e168d-0dcb-476c-81f0-bc7cd88d4156	adminonu	admin@onu.net	$2b$12$ASSrnPIYYNwwu4MzWtK3muvilblRCDh9X.yNVA1cLxaiUeabJuo.q	super_admin	active	2026-11-14 18:01:19.846144+00	2026-11-14 18:01:19.846144+00	2026-11-22 07:43:48.520106+00	
\.


--
-- Data for Name: videos; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.videos (id, title, description, source_type, object_key, external_url, thumbnail_key, status, author_id, published_at, created_at, updated_at) FROM stdin;
278f6839-b5a4-4a7a-aee0-fe0929ebc031	Test Video 1		external	\N	https://youtu.be/mGvAZSBn-Ks?si=Z29X_G4MNl9WjzUM	\N	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-16 12:11:41.767124+00	2026-11-16 12:11:36.731035+00	2026-11-16 12:11:41.767124+00
5d252348-2daf-4cc2-b883-1061f7ddff29	Test Video 2		external	\N	https://youtu.be/2hb3H0t7Gt4?si=U0CNAaKrYHYh7JLb	\N	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-16 12:12:03.423891+00	2026-11-16 12:12:00.210362+00	2026-11-16 12:12:03.423891+00
e654960a-c999-4a5c-a619-ce22d661b6c4	Test Video 3		external	\N	https://youtu.be/Sn3chaxmNqM?si=o_K8-qD5kO0aUvKV	\N	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-16 12:12:23.250401+00	2026-11-16 12:12:20.141498+00	2026-11-16 12:12:23.250401+00
806b28d8-2629-439d-b58f-75cd90400848	Test Video 4	Test description	external	\N	https://youtu.be/dBJN9zWVWc8?si=DOQ5dG3Il3fIX5un	\N	published	5e8e168d-0dcb-476c-81f0-bc7cd88d4156	2026-11-16 12:13:22.096467+00	2026-11-16 12:13:18.4162+00	2026-11-16 12:13:22.096467+00
\.


--
-- Name: activity_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.activity_log_id_seq', 22, true);


--
-- Name: activity_log activity_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_log
    ADD CONSTRAINT activity_log_pkey PRIMARY KEY (id);


--
-- Name: admin_content_entries admin_content_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_content_entries
    ADD CONSTRAINT admin_content_entries_pkey PRIMARY KEY (id);


--
-- Name: admin_sessions admin_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_sessions
    ADD CONSTRAINT admin_sessions_pkey PRIMARY KEY (id);


--
-- Name: admin_sessions admin_sessions_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_sessions
    ADD CONSTRAINT admin_sessions_token_hash_key UNIQUE (token_hash);


--
-- Name: article_placements article_placements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_placements
    ADD CONSTRAINT article_placements_pkey PRIMARY KEY (article_id, placement);


--
-- Name: articles articles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_pkey PRIMARY KEY (id);


--
-- Name: articles articles_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_slug_key UNIQUE (slug);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: categories categories_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_slug_key UNIQUE (slug);


--
-- Name: media_assets media_assets_object_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_assets
    ADD CONSTRAINT media_assets_object_key_key UNIQUE (object_key);


--
-- Name: media_assets media_assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_assets
    ADD CONSTRAINT media_assets_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (filename);


--
-- Name: section_articles section_articles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.section_articles
    ADD CONSTRAINT section_articles_pkey PRIMARY KEY (section_id, article_id);


--
-- Name: site_sections site_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_sections
    ADD CONSTRAINT site_sections_pkey PRIMARY KEY (id);


--
-- Name: site_sections site_sections_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_sections
    ADD CONSTRAINT site_sections_slug_key UNIQUE (slug);


--
-- Name: site_settings site_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_settings
    ADD CONSTRAINT site_settings_pkey PRIMARY KEY (setting_key);


--
-- Name: test_seed_articles test_seed_articles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_seed_articles
    ADD CONSTRAINT test_seed_articles_pkey PRIMARY KEY (article_id);


--
-- Name: test_seed_assets test_seed_assets_media_asset_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_seed_assets
    ADD CONSTRAINT test_seed_assets_media_asset_id_key UNIQUE (media_asset_id);


--
-- Name: test_seed_assets test_seed_assets_object_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_seed_assets
    ADD CONSTRAINT test_seed_assets_object_key_key UNIQUE (object_key);


--
-- Name: test_seed_assets test_seed_assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_seed_assets
    ADD CONSTRAINT test_seed_assets_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: videos videos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.videos
    ADD CONSTRAINT videos_pkey PRIMARY KEY (id);


--
-- Name: activity_log_actor_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_log_actor_id_idx ON public.activity_log USING btree (actor_id);


--
-- Name: activity_log_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_log_created_at_idx ON public.activity_log USING btree (created_at DESC);


--
-- Name: admin_content_entries_module_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX admin_content_entries_module_idx ON public.admin_content_entries USING btree (module, sort_order, created_at DESC);


--
-- Name: admin_sessions_expires_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX admin_sessions_expires_at_idx ON public.admin_sessions USING btree (expires_at);


--
-- Name: admin_sessions_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX admin_sessions_user_id_idx ON public.admin_sessions USING btree (user_id);


--
-- Name: article_placements_placement_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX article_placements_placement_idx ON public.article_placements USING btree (placement, sort_order);


--
-- Name: articles_author_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX articles_author_id_idx ON public.articles USING btree (author_id);


--
-- Name: articles_category_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX articles_category_id_idx ON public.articles USING btree (category_id);


--
-- Name: articles_status_published_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX articles_status_published_at_idx ON public.articles USING btree (status, published_at DESC);


--
-- Name: media_assets_uploader_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX media_assets_uploader_id_idx ON public.media_assets USING btree (uploader_id);


--
-- Name: test_seed_articles_category_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX test_seed_articles_category_id_idx ON public.test_seed_articles USING btree (category_id);


--
-- Name: users_email_lower_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email_lower_idx ON public.users USING btree (lower(email));


--
-- Name: users_username_lower_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_username_lower_idx ON public.users USING btree (lower(username));


--
-- Name: videos_author_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX videos_author_id_idx ON public.videos USING btree (author_id);


--
-- Name: videos_status_published_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX videos_status_published_at_idx ON public.videos USING btree (status, published_at DESC);


--
-- Name: activity_log activity_log_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_log
    ADD CONSTRAINT activity_log_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: admin_content_entries admin_content_entries_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_content_entries
    ADD CONSTRAINT admin_content_entries_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: admin_sessions admin_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_sessions
    ADD CONSTRAINT admin_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: article_placements article_placements_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_placements
    ADD CONSTRAINT article_placements_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;


--
-- Name: articles articles_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: articles articles_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE RESTRICT;


--
-- Name: articles articles_image_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_image_key_fkey FOREIGN KEY (image_key) REFERENCES public.media_assets(object_key) ON DELETE RESTRICT;


--
-- Name: categories categories_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.categories(id) ON DELETE RESTRICT;


--
-- Name: media_assets media_assets_uploader_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_assets
    ADD CONSTRAINT media_assets_uploader_id_fkey FOREIGN KEY (uploader_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: section_articles section_articles_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.section_articles
    ADD CONSTRAINT section_articles_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;


--
-- Name: section_articles section_articles_section_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.section_articles
    ADD CONSTRAINT section_articles_section_id_fkey FOREIGN KEY (section_id) REFERENCES public.site_sections(id) ON DELETE CASCADE;


--
-- Name: test_seed_articles test_seed_articles_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_seed_articles
    ADD CONSTRAINT test_seed_articles_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;


--
-- Name: test_seed_articles test_seed_articles_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_seed_articles
    ADD CONSTRAINT test_seed_articles_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE RESTRICT;


--
-- Name: test_seed_assets test_seed_assets_media_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_seed_assets
    ADD CONSTRAINT test_seed_assets_media_asset_id_fkey FOREIGN KEY (media_asset_id) REFERENCES public.media_assets(id) ON DELETE CASCADE;


--
-- Name: videos videos_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.videos
    ADD CONSTRAINT videos_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: videos videos_object_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.videos
    ADD CONSTRAINT videos_object_key_fkey FOREIGN KEY (object_key) REFERENCES public.media_assets(object_key) ON DELETE RESTRICT;


--
-- Name: videos videos_thumbnail_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.videos
    ADD CONSTRAINT videos_thumbnail_key_fkey FOREIGN KEY (thumbnail_key) REFERENCES public.media_assets(object_key) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

\unrestrict Ayi48NJm5dpkkAHGaZ1vo0ZuhReylCdbZor49ZN8T1zV7aRz1RdzFiyIiLSWF5k

