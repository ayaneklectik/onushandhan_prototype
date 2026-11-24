import { DeleteObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { config } from "../server/config.js";
import { pool } from "../server/db.js";
const BATCH="24ghontatv-100-v1";
let s3;
function storage(){const m=config.media;if(!m.bucket||!m.endpoint||!m.accessKeyId||!m.secretAccessKey)throw Error("R2 is not fully configured");s3 ||= new S3Client({region:m.region,endpoint:m.endpoint,forcePathStyle:m.forcePathStyle,credentials:{accessKeyId:m.accessKeyId,secretAccessKey:m.secretAccessKey}});return s3;}
async function main(){
 const execute=process.argv.includes("--execute"),db=await pool.connect();let count=0,assets=[];
 try{
  await db.query("BEGIN");
  const found=await db.query("SELECT article_id FROM external_article_imports WHERE batch_key=$1 FOR UPDATE",[BATCH]);count=found.rowCount;
  const rows=await db.query("SELECT id,object_key FROM media_assets ma WHERE ma.object_key LIKE 'imports/24ghontatv/%' AND NOT EXISTS (SELECT 1 FROM articles a WHERE a.image_key=ma.object_key) AND NOT EXISTS (SELECT 1 FROM videos v WHERE v.object_key=ma.object_key OR v.thumbnail_key=ma.object_key) FOR UPDATE OF ma");
  assets=rows.rows;await db.query("ROLLBACK");
 }catch(e){await db.query("ROLLBACK");throw e;}finally{db.release();}
 console.log("Tracked imported articles:",count,"| currently unreferenced import assets:",assets.length);
 if(!execute){console.log("Dry-run only. Execute with npm run import:24ghonta:remove -- --execute");return;}
 const client=await pool.connect();
 try{
  await client.query("BEGIN");
  await client.query("DELETE FROM articles WHERE id IN (SELECT article_id FROM external_article_imports WHERE batch_key=$1)",[BATCH]);
  const rows=await client.query("SELECT id,object_key FROM media_assets ma WHERE ma.object_key LIKE 'imports/24ghontatv/%' AND NOT EXISTS (SELECT 1 FROM articles a WHERE a.image_key=ma.object_key) AND NOT EXISTS (SELECT 1 FROM videos v WHERE v.object_key=ma.object_key OR v.thumbnail_key=ma.object_key) FOR UPDATE OF ma");
  assets=rows.rows;for(const a of assets)await client.query("DELETE FROM media_assets WHERE id=$1",[a.id]);
  await client.query("COMMIT");
 }catch(e){await client.query("ROLLBACK");throw e;}finally{client.release();}
 for(const a of assets)await storage().send(new DeleteObjectCommand({Bucket:config.media.bucket,Key:a.object_key}));
 console.log("Removed tracked imported articles and",assets.length,"unreferenced import images. Existing articles/media were preserved.");
}
main().catch(e=>{console.error("Cleanup failed:",e);process.exitCode=1;}).finally(()=>pool.end());
