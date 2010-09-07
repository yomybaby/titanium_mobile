/**
 * 
 */
package org.appcelerator.titanium.cache;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.concurrent.FutureTask;
import java.util.zip.CRC32;

import org.apache.commons.codec.digest.DigestUtils;
import org.appcelerator.titanium.util.Log;
import org.appcelerator.titanium.util.TiConfig;

/**
 * @author dthorp
 *
 */
public class DownloadTask<Void> extends FutureTask<Void> 
{
	private static final String LCAT = "DownloadTask";
	private static boolean DBG = TiConfig.LOGD;
	
	public DownloadTask(final TiCacheManager cacheManager, final String key)
	{
		super(new Runnable(){

			@Override
			public void run() {
				InputStream is = null;
				OutputStream os = null;
				try {
					if (DBG) {
						Log.d(LCAT, "Downloading: " + key);
					}
					URL url = new URL(key);
					HttpURLConnection connection = (HttpURLConnection) url.openConnection();
					connection.setDoInput(true);
					connection.setDoOutput(false);
					connection.connect();
					is = connection.getInputStream(); // We want to cache here.
					
					StringBuilder sb = new StringBuilder();
					sb.append("K")
						.append(DigestUtils.md5Hex(key).substring(0, 6))
						.append("-")
						.append(System.currentTimeMillis());
					String cacheKey = sb.toString(); 

					File f = cacheManager.getDataFile(cacheKey);
					f.createNewFile();
					os = new BufferedOutputStream(new FileOutputStream(f), 8096);
					byte[] buf = new byte[8096];
					int len = -1;
					while((len = is.read(buf)) > 0) {
						os.write(buf,0,len);
					}
					os.close();
					os = null;
					
					cacheManager.fileReady(key, cacheKey);
				} catch (MalformedURLException e) {
					cacheManager.error(key, e);
				} catch (IOException e) {
					cacheManager.error(key, e);
				} catch (Throwable t) {
					cacheManager.error(key, t);
				} finally {
					if (is != null) {
						try {
							is.close();
						} catch (IOException ignore) {
							
						}
					}
					if (os != null) {
						try {
							os.close();
						} catch (IOException ignore) {
							
						}
					}
				}
			}
		}, null);
	}
}
