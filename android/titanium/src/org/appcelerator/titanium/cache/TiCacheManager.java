/**
 * 
 */
package org.appcelerator.titanium.cache;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileFilter;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.HashMap;
import java.util.HashSet;

import org.appcelerator.titanium.util.TiConfig;

import android.util.Log;

/**
 * @author dthorp
 *
 */
public class TiCacheManager 
{
	private static final String LCAT = "TiCacheMgr";
	private static boolean DBG = TiConfig.LOGD;
	
	private static final String ENTRY_KEY_SUFFIX = ".entry";
	private static final String ENTRY_DATA_SUFFIX = ".data";
	
	private static final int MAX_ENTRIES = 100;
	
	private File cachePath;
	private int maxEntries;
	
	private HashMap<String, TiCacheEntry> cacheMap;
	
	public interface TiCacheCallback 
	{
		public void fileReady(File f);
		public void error(Throwable t); //TODO Something
	};
	
	public TiCacheManager(String cachePath) 
	{
		this.cachePath = new File(cachePath);
		maxEntries = MAX_ENTRIES;
		//TODO initialize from properties
		
		cacheMap = new HashMap<String, TiCacheEntry>(maxEntries);
	}
	
	public void init()
		throws TiCacheManagerException
	{
		if (!cachePath.exists()) {
			if (!cachePath.mkdirs()) {
				throw new TiCacheManagerException("Unable to create cache directory.");
			}
		}
		
		// See if there is cache data to load.	
		loadCache();
	}
	
	private void loadCache()
	{
		File[] dataFiles = cachePath.listFiles(new FileFilter()
		{
			@Override
			public boolean accept(File f) {
				if (f.getName().endsWith(ENTRY_DATA_SUFFIX)) {
					return true;
				}
				return false;
			}
		});
		
		HashSet<File> dataFileSet = new HashSet<File>();
		for (File f : dataFiles) {
			dataFileSet.add(f);
		}
		dataFiles = null;

		File[] keyFiles = cachePath.listFiles(new FileFilter()
		{
			@Override
			public boolean accept(File f) {
				if (f.getName().endsWith(ENTRY_KEY_SUFFIX)) {
					return true;
				}
				return false;
			}
		});
		
		for(File keyFile : keyFiles) {
			
			String cacheKey = cacheKeyFrom(keyFile.getName());
			
			File dataFile = getDataFile(cacheKey);
			if (dataFile.exists()) {
				dataFileSet.remove(dataFile);
				try {
					TiCacheEntry ce = TiCacheEntry.load(this, cacheKey);
					if (ce != null) {
						cacheMap.put(ce.key, ce);
						if (DBG) {
							Log.d(LCAT, "Added entry " + ce);
						}
					} else {
						if (DBG) {
							Log.w(LCAT, "Invalid or missing entry for cacheKey: " + cacheKey + ". removing.");
						}
						removeFileCacheEntry(cacheKey);
					}
				} catch (TiCacheManagerException e) {
					Log.e(LCAT, "Failed loading entry " + e.getMessage());
					removeFileCacheEntry(cacheKey);
				}
			} else {
				if (DBG) {
					Log.i(LCAT, "Missing data file for key entry " + cacheKey + " removing key.");
				}
				removeFileCacheEntry(cacheKey);
			}
		}
		
		// Get rid of orphaned data files.
		for(File f : dataFileSet){
			f.delete();
		}
		dataFileSet.clear();
	}
	
	public void get(final String key, final TiCacheCallback callback) 
	{
		//TODO - Should probably return a Future of some sort to allow
		// canceling a fetch.
		
		synchronized(cacheMap) {
			TiCacheEntry ce = cacheMap.get(key);
			if (ce != null && ce.valid()) {
				//TODO async?
				ce.accessed();
				callback.fileReady(getDataFile(ce.cacheKey));
			} else {
				// Cleanup invalid entry
				if (ce != null) {
					if (DBG) {
						Log.w(LCAT, "Invalid cache entry for " + key + " removing.");
					}
					cacheMap.remove(key);
					removeFileCacheEntry(ce.cacheKey);
					ce = null;
				}
				
				final TiCacheManager fmgr = this;
				
				//TODO use bounded queue
				Thread t = new Thread(new Runnable()
				{
					@Override
					public void run() {
						InputStream is = null;
						OutputStream os = null;
						try {
							URL url = new URL(key);
							HttpURLConnection connection = (HttpURLConnection) url.openConnection();
							connection.setDoInput(true);
							connection.setDoOutput(false);
							connection.connect();
							is = connection.getInputStream(); // We want to cache here.
							String cacheKey = "K" + System.currentTimeMillis();
							File f = getDataFile(cacheKey);
							f.createNewFile();
							os = new BufferedOutputStream(new FileOutputStream(f), 8096);
							byte[] buf = new byte[8096];
							int len = -1;
							while((len = is.read(buf)) > 0) {
								os.write(buf,0,len);
							}
							os.close();
							os = null;
							
							TiCacheEntry ce = TiCacheEntry.create(fmgr, key, cacheKey);
							if (ce != null) {
								synchronized(cacheMap) {
									cacheMap.put(key, ce);
									callback.fileReady(getDataFile(ce.cacheKey));
								}
							} else {
								callback.error(null);
							}
					} catch (MalformedURLException e) {
						callback.error(e);
					} catch (IOException e) {
						callback.error(e);
					} catch (Throwable t) {
						callback.error(t);
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
				});
				t.start();
			}
		}
	}
	
	File getCachePath() 
	{
		return cachePath;
	}
	
	File getKeyFile(String cacheKey)
	{
		return new File(cachePath, cacheKey + ENTRY_KEY_SUFFIX);
	}
	
	File getDataFile(String cacheKey)
	{
		return new File(cachePath, cacheKey + ENTRY_DATA_SUFFIX);
	}
	
	
	void removeFileCacheEntry(String cacheKey)
	{
		File keyFile = getKeyFile(cacheKey);
		File dataFile = getDataFile(cacheKey);
		if (keyFile != null) {
			keyFile.delete();					
		}
		if (dataFile != null) {
			dataFile.delete();
		}
	
	}
	
	private String cacheKeyFrom(String name)
	{
		String result = null;
		int index = name.lastIndexOf('.');
		if (index >= 0) {
			result = name.substring(0, index);
		}
		
		return result;
	}
}
