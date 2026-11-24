import { randomUUID } from "node:crypto";
import { DeleteObjectCommand, PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { config } from "../server/config.js";
import { pool } from "../server/db.js";

const ROOT = "https://24ghontatv.com";
const BATCH = "24ghontatv-100-v1";
const MONTHS = {"জানুয়ারি":0,"জানুয়ারি":0,"ফেব্রুয়ারি":1,"ফেব্রুয়ারি":1,"মার্চ":2,"এপ্রিল":3,"মে":4,"জুন":5,"জুলাই":6,"আগস্ট":7,"সেপ্টেম্বর":8,"অক্টোবর":9,"নভেম্বর":10,"ডিসেম্বর":11};
const MAP = {"মতামত":"opinion","বিশ্লেষণ":"opinion","রাজনীতি":"power-and-influence","দুর্নীতি":"corruption","অপরাধ":"organized-crime","আইন ও বিচার":"organized-crime","মানবাধিকার":"freedom-and-repression","বিনোদন":"content-stories","লাইফস্টাইল":"content-stories","শিক্ষা":"content-stories","কৃষি":"content-stories"};
const IMAGE_HOSTS = new Set(["media.concordleads.cloud"]);
let s3;
function storage() {
  const m=config.media;
  if(!m.bucket||!m.endpoint||!m.accessKeyId||!m.secretAccessKey||!m.publicBaseUrl) throw new Error("R2 is not fully configured. Check existing MEDIA_* settings in Dokploy.");
  s3 ||= new S3Client({region:m.region,endpoint:m.endpoint,forcePathStyle:m.forcePathStyle,credentials:{accessKeyId:m.accessKeyId,secretAccessKey:m.secretAccessKey}});
  return s3;
}
function entities(s){return s.replace(/&nbsp;|&#160;/gi," ").replace(/&amp;/gi,"&").replace(/&quot;/gi,'"').replace(/&#39;|&apos;/gi,"'").replace(/&lt;/gi,"<").replace(/&gt;/gi,">").replace(/&#(\d+);/g,(_,n)=>String.fromCodePoint(+n)).replace(/&#x([0-9a-f]+);/gi,(_,n)=>String.fromCodePoint(parseInt(n,16)));}
function plain(s){return entities((s||"").replace(/<script\b[\s\S]*?<\/script>/gi," ").replace(/<style\b[\s\S]*?<\/style>/gi," ").replace(/<[^>]+>/g," ")).replace(/\s+/g," ").trim();}
function abs(s,base){try{return new URL(entities(s),base).href;}catch{return null;}}
function articleUrl(s){const u=abs(s,ROOT);if(!u)return null;const x=new URL(u);return x.protocol==="https:"&&["24ghontatv.com","www.24ghontatv.com"].includes(x.hostname)&&/^\/news\/\d+\/?$/.test(x.pathname)?x.origin+x.pathname.replace(/\/$/,""):null;}
function links(html){return [...new Set([...html.matchAll(/href=["']([^"']*\/news\/\d+\/?)["']/gi)].map(m=>articleUrl(m[1])).filter(Boolean))];}
async function html(url){const r=await fetch(url,{headers:{"user-agent":"Onushondhan authorized content migration"}});if(!r.ok)throw Error("HTTP "+r.status+" "+url);if(!["24ghontatv.com","www.24ghontatv.com"].includes(new URL(r.url).hostname))throw Error("Unexpected redirect host");return r.text();}
function dateFrom(s){const m=s.match(/প্রকাশ\s*:\s*([০-৯0-9]{1,2}\s+[^\s|,]+,?\s+[০-৯0-9]{4})\s*\|\s*([০-৯0-9]{1,2}:[০-৯0-9]{2})/);if(!m)return null;const d=m[1].replace(/[০-৯]/g,c=>String("০১২৩৪৫৬৭৮৯".indexOf(c))).replace(",","").trim().split(/\s+/);const t=m[2].replace(/[০-৯]/g,c=>String("০১২৩৪৫৬৭৮৯".indexOf(c))).split(":").map(Number);const month=MONTHS[d[1]];if(month===undefined)return null;const v=new Date(Date.UTC(+d[2],month,+d[0],t[0],t[1]));return Number.isNaN(v.getTime())?null:v.toISOString();}
function bodyHtml(a){
 const src=a.replace(/<figure\b[\s\S]*?<\/figure>/gi," ").replace(/<(script|style|nav|aside|form)\b[\s\S]*?<\/\1>/gi," ");
 const out=[];
 for(const m of src.matchAll(/<(p|h2|h3|blockquote|ul|ol)\b[^>]*>([\s\S]*?)<\/\1>/gi)){
  const tag=m[1].toLowerCase();let inner=m[2].replace(/<br\s*\/?>/gi,"\n").replace(/<(strong|b)\b[^>]*>/gi,"<strong>").replace(/<\/(b|strong)>/gi,"</strong>").replace(/<(em|i)\b[^>]*>/gi,"<em>").replace(/<\/(i|em)>/gi,"</em>").replace(/<(?!\/?(strong|em)\b)[^>]+>/gi,"");
  inner=entities(inner).trim();if(plain(inner).length<2)continue;
  if(tag==="ul"||tag==="ol"){const li=[...m[2].matchAll(/<li\b[^>]*>([\s\S]*?)<\/li>/gi)].map(x=>"<li>"+plain(x[1])+"</li>").join("");if(li)out.push("<"+tag+">"+li+"</"+tag+">");}
  else out.push("<"+tag+">"+inner+"</"+tag+">");
 }
 return out.join("\n");
}
function imageFrom(a){
 const fig=a.match(/<figure\b[\s\S]*?<\/figure>/i)?.[0];const img=fig?.match(/<img\b[^>]*>/i)?.[0];const src=img?.match(/\bsrc=["']([^"']+)["']/i)?.[1];if(!src)return null;
 const url=abs(src,ROOT);if(!url)return null;const u=new URL(url);if(u.protocol!=="https:"||!IMAGE_HOSTS.has(u.hostname))return null;
 return {url,alt:entities(img.match(/\balt=["']([^"']*)["']/i)?.[1]||"")};
}
async function readArticle(url){
 const page=await html(url);const a=page.match(/<article\b[\s\S]*?<\/article>/i)?.[0];if(!a)throw Error("Article element missing");
 const title=plain(a.match(/<h1\b[^>]*>([\s\S]*?)<\/h1>/i)?.[1]||"");
 const ps=[...a.matchAll(/<p\b[^>]*>([\s\S]*?)<\/p>/gi)].map(x=>plain(x[1])).filter(x=>x.length>35);
 const category=plain(a.match(/<div\b[^>]*>\s*([^<]{2,50})\s*<\/div>/i)?.[1]||"");
 const body=bodyHtml(a),image=imageFrom(a),publishedAt=dateFrom(a),id=url.match(/\/news\/(\d+)/)?.[1];
 if(!title||!body||!image||!publishedAt)throw Error("Missing title/body/main figure image/publication date");
 const headline=ps.find(x=>x!==title&&x.length<240)||"";
 const summary=ps.find(x=>x!==title&&x!==headline)||headline||title;
 return {id,url,title,headline,summary,body,category,image,publishedAt};
}
async function discover(){
 const home=await html(ROOT+"/");const cats=new Set(["/category/জাতীয়","/category/সারাদেশ"]);
 for(const m of home.matchAll(/href=["']([^"']*\/category\/[^"'?#]+)["']/gi)){const u=abs(m[1],ROOT);if(u&&["24ghontatv.com","www.24ghontatv.com"].includes(new URL(u).hostname))cats.add(new URL(u).pathname);}
 const all=new Set(links(home));
 for(const p of cats){try{const page=await html(ROOT+encodeURI(p));links(page).forEach(x=>all.add(x));}catch(e){console.warn("Skip category",p,e.message);}}
 return [...all];
}
async function download(url){
 const u=new URL(url);if(u.protocol!=="https:"||!IMAGE_HOSTS.has(u.hostname))throw Error("Image host not allowlisted");
 const r=await fetch(url,{redirect:"error"});if(!r.ok)throw Error("Image HTTP "+r.status);
 const type=(r.headers.get("content-type")||"").split(";")[0].toLowerCase();
 const ext={"image/jpeg":".jpg","image/png":".png","image/webp":".webp","image/avif":".avif"}[type];if(!ext)throw Error("Unsupported image type "+type);
 const declared=Number(r.headers.get("content-length")||0);if(declared>config.media.maxImageBytes)throw Error("Image exceeds upload limit");
 const bytes=Buffer.from(await r.arrayBuffer());if(!bytes.length||bytes.length>config.media.maxImageBytes)throw Error("Invalid/oversize image");
 return {bytes,type,ext};
}
function shuffle(a){const x=[...a];for(let i=x.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[x[i],x[j]]=[x[j],x[i]];}return x;}
async function main(){
 const execute=process.argv.includes("--execute");
 if(process.argv.includes("--help")){console.log("Dry-run: npm run import:24ghonta | Execute: npm run import:24ghonta -- --execute");return;}
 const [users,cats,tracked]=await Promise.all([
  pool.query("SELECT id FROM users WHERE username='adminonu' AND status='active' LIMIT 1"),
  pool.query("SELECT id,slug,name FROM categories WHERE is_enabled=true"),
  pool.query("SELECT source_url FROM external_article_imports")
 ]);
 if(!users.rowCount)throw Error("Active adminonu author not found");
 const categoryBySlug=new Map(cats.rows.map(x=>[x.slug,x]));
 const known=new Set(tracked.rows.map(x=>x.source_url));
 const urls=(await discover()).filter(x=>!known.has(x));
 console.log("Discovered",urls.length,"new article URLs.");
 const valid=[],skipped=[];
 for(const url of urls){try{const a=await readArticle(url);const slug=MAP[a.category]||"reports";a.categoryId=categoryBySlug.get(slug)?.id||categoryBySlug.get("reports")?.id;if(!a.categoryId)throw Error("No destination category");valid.push(a);}catch(e){skipped.push({url,reason:e.message});}}
 const selected=shuffle(valid).slice(0,100);
 console.log("Valid:",valid.length,"Selected:",selected.length,"Skipped:",skipped.length);
 if(selected.length!==100){console.log("No changes made. Skipped examples:",skipped.slice(0,10));throw Error("Need 100 valid articles; found "+selected.length);}
 console.log("DRY-RUN SAMPLE:");
 for(const a of selected.slice(0,10))console.log(JSON.stringify({id:a.id,title:a.title,sourceCategory:a.category,destinationCategory:cats.rows.find(c=>c.id===a.categoryId)?.name,publishedAt:a.publishedAt,image:a.image.url,source:a.url},null,2));
 console.log("Planned total: 100 articles + 100 main images.");
 if(!execute){console.log("Dry-run only. Review results, then add -- --execute.");return;}
 const client=storage();let done=0;
 for(const a of selected){
  const img=await download(a.image.url),key="imports/24ghontatv/"+a.id+img.ext,articleId=randomUUID(),assetId=randomUUID();let uploaded=false;
  try{
   await client.send(new PutObjectCommand({Bucket:config.media.bucket,Key:key,Body:img.bytes,ContentType:img.type,CacheControl:"public, max-age=31536000, immutable"}));uploaded=true;
   const db=await pool.connect();
   try{
    await db.query("BEGIN");
    await db.query("INSERT INTO media_assets (id,object_key,media_type,content_type,size_bytes,status,uploader_id) VALUES ($1,$2,'image',$3,$4,'ready',$5)",[assetId,key,img.type,img.bytes.length,users.rows[0].id]);
    await db.query("INSERT INTO articles (id,slug,title,headline,summary,body,image_key,image_alt,category_id,status,author_id,published_at,attribution,image_caption,image_credit) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'published',$10,$11,$12,'','')",[articleId,"24ghontatv-"+a.id,a.title,a.headline,a.summary,a.body,key,a.image.alt||a.title,a.categoryId,users.rows[0].id,a.publishedAt,"সূত্র: ২৪ঘণ্টা"]);
    await db.query("INSERT INTO external_article_imports (article_id,source_url,source_name,batch_key,source_published_at) VALUES ($1,$2,'24GhontaTV',$3,$4)",[articleId,a.url,BATCH,a.publishedAt]);
    await db.query("COMMIT");
   }catch(e){await db.query("ROLLBACK");throw e;}finally{db.release();}
   done++;console.log("Imported",done+"/100",a.title);
  }catch(e){if(uploaded)try{await client.send(new DeleteObjectCommand({Bucket:config.media.bucket,Key:key}));}catch(clean){console.error("Orphan cleanup failed:",key,clean.message);}throw e;}
 }
 console.log("Import complete:",done,"articles. Existing content was not modified.");
}
main().catch(e=>{console.error("Import failed:",e);process.exitCode=1;}).finally(()=>pool.end());
