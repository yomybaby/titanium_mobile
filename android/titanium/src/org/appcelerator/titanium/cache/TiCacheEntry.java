/**
 * 
 */
package org.appcelerator.titanium.cache;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.lang.ref.SoftReference;

import org.appcelerator.titanium.util.Log;
import org.appcelerator.titanium.util.TiConfig;


public class TiCacheEntry 
{
	private static final String LCAT = "TiCacheEntry";
	private static boolean DBG = TiConfig.LOGD;
	
	private static final int VERSION_ID = 1;
	
	String key; // The path as requested by the user.
	String cacheKey; // The name of the file in the cache w/o extension
	long fileSize; // Size of file on disk
	long lastModified; // Time from server
	long lastAccessed; // Last request through manager
	
	private SoftReference<TiCacheManager> softManager;
	
	private TiCacheEntry(TiCacheManager manager)
	{
		key = null;
		cacheKey = ""; //TODO generate
		softManager = new SoftReference<TiCacheManager>(manager);
		fileSize = 0;
		lastModified = 0;
		lastAccessed = 0;
	}
	
	public void accessed() 
	{
		TiCacheManager mgr = softManager.get();
		
		File keyFile = mgr.getKeyFile(cacheKey);
		lastAccessed = System.currentTimeMillis();
		keyFile.setLastModified(lastAccessed);
	}
	
	public boolean valid()
	{
		boolean valid = false;
		
		TiCacheManager mgr = softManager.get();
		
		File keyFile = mgr.getKeyFile(cacheKey);
		File dataFile = mgr.getDataFile(cacheKey);
		if (keyFile != null && keyFile.exists() && 
				dataFile != null && dataFile.exists()) 
		{
			valid = true;
		}
			
		return valid;
	}
	
	public boolean save()
	{
		boolean saved = false;
		DataOutputStream os = null;
		
		TiCacheManager mgr = softManager.get(); // expect it to be non-null, crash hard if not, for now.
		File keyFile = mgr.getKeyFile(cacheKey);
		
		try {
			os = new DataOutputStream(new FileOutputStream(keyFile));
			
			os.writeInt(VERSION_ID);
			os.writeUTF(key);
			os.writeUTF(cacheKey);
			os.writeLong(fileSize);
			os.writeLong(lastModified);
			os.writeLong(lastAccessed);
			os.flush();
			os.close();
			os = null;
			
			saved = true;
		} catch (IOException e) {
			Log.e(LCAT, "Unable to save item to cache. " + e.getMessage(), e);
		} finally {
			if (os != null) {
				try {
					os.close();
				} catch (IOException ignore) {
					
				}
			}
		}
		
		return saved;
	}
	
	public static final TiCacheEntry create(TiCacheManager mgr, String key, String cacheKey)
	{
		TiCacheEntry ce = new TiCacheEntry(mgr);
		ce.key = key;
		ce.cacheKey = cacheKey;
		File dataFile = mgr.getDataFile(cacheKey);
		ce.fileSize = dataFile.length();
		ce.lastModified = dataFile.lastModified();
		ce.lastAccessed = ce.lastModified;
		ce.save();
		
		ce.accessed();
		
		return ce;
	}
	
	public static final TiCacheEntry load(TiCacheManager mgr, String cacheKey) 
		throws TiCacheManagerException
	{
		TiCacheEntry ce = new TiCacheEntry(mgr);
		
		File keyFile = mgr.getKeyFile(cacheKey);
		File dataFile = mgr.getDataFile(cacheKey);
		
		DataInputStream is = null;
		boolean dirty = false;
		
		try {
			is = new DataInputStream(new FileInputStream(keyFile));
			int versionId = is.readInt();
			if (versionId == VERSION_ID) {
				ce.key = is.readUTF();
				ce.cacheKey = is.readUTF();
				if (!cacheKey.equals(ce.cacheKey)) {
					throw new TiCacheManagerException("Corrupted Cache. Key in file does not match, name");
				}
				ce.fileSize = is.readLong();
				if (ce.fileSize != dataFile.length()) {
					if (DBG) {
						Log.d(LCAT, "File Size: Cache entry " + ce.fileSize + " != actual " + dataFile.length() + " using actual.");
					}
					ce.fileSize = dataFile.length();
					dirty = true;
				}
				ce.lastModified = is.readLong();
				if (ce.lastModified != dataFile.lastModified()) {
					if (DBG) {
						Log.d(LCAT, "File lastModified : Cache entry " + ce.lastModified + " != actual " + dataFile.lastModified() + " using actual.");
					}
					ce.lastModified = dataFile.lastModified();
					dirty = true;
				}
				// Use lastModified of key file to determine the last time the file was accessed.
				ce.lastAccessed = is.readLong();
				if (ce.lastAccessed != keyFile.lastModified()) {
					if (DBG) {
						Log.d(LCAT, "Key File lastAccessed : Cache entry " + ce.lastAccessed + " != actual " + dataFile.lastModified() + " using actual.");
					}
					ce.lastAccessed = keyFile.lastModified();
					dirty = true;
				}
				
				if (dirty) {
					if (DBG) {
						Log.i(LCAT, "Cache entry was out of sync. Persisting.");
					}
					ce.save();
				}
			} else {
				Log.w(LCAT, "Unsupported Cache Version " + versionId + " expected " + VERSION_ID + " core implementation needs updating.");
				ce = null;
			}
			
			is.close();
			is = null;
		} catch (IOException e) {
			Log.e(LCAT, "Error while trying to load cache entry for key " + cacheKey + ". " + e.getMessage(), e);
			ce = null;
		} finally {
			if (is != null) {
				try {
					is.close();
				} catch (IOException ignore) {
					
				}
			}
		}
		return ce;
	}

	@Override
	public String toString() 
	{
		StringBuilder sb = new StringBuilder(300);
		sb.append("key: " ).append(key).append("\n")
			.append("cacheKey: ").append(cacheKey).append("\n")
			.append("lastAccessed: ").append(lastAccessed).append("\n")
			.append("lastModified: ").append(lastModified).append("\n")
			.append("fileSize: ").append(fileSize)
			;
		return sb.toString();
	}	
}
