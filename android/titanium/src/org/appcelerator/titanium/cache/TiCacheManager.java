/**
 * 
 */
package org.appcelerator.titanium.cache;

import java.io.File;
import java.io.FileFilter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadPoolExecutor;

import org.appcelerator.titanium.util.Log;
import org.appcelerator.titanium.util.TiConfig;

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
	private HashMap<String, ArrayList<TiCacheCallback>> completionListeners;
	private ThreadPoolExecutor executor;
	
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
		completionListeners = new HashMap<String, ArrayList<TiCacheCallback>>(100);
		executor = (ThreadPoolExecutor) Executors.newCachedThreadPool();
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
						if (cacheMap.containsKey(ce.key)) {
							Log.e(LCAT, "Duplicate Cache Entry for key: " + ce.key);
						}
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
				Log.e(LCAT, "CACHE HIT: " + key);
				//TODO async?
				ce.accessed();
				callback.fileReady(getDataFile(ce.cacheKey));
				Log.w(LCAT, "Notified for : " + key);
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
				
				// What we need here is to separate out the download as a specific task keyed
				// by Key. Then have the ability to set multiple listeners on the download request.
				
				ArrayList<TiCacheCallback> callbacks;
				boolean requiresTask = false;
				if (completionListeners.containsKey(key)) {
					callbacks = completionListeners.get(key);
				} else {
					callbacks = new ArrayList<TiCacheCallback>();
					completionListeners.put(key, callbacks);
					requiresTask = true;
				}
				callbacks.add(callback);
				
				if (requiresTask) {
					DownloadTask<Void> task = new DownloadTask<Void>(this, key);
					executor.execute(task);
				}
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
	
	void fileReady(String key, String cacheKey) 
	{
		synchronized(cacheMap) {
			TiCacheEntry ce = TiCacheEntry.create(this, key, cacheKey);
			if (ce != null) {
				if (cacheMap.containsKey(key)) {
					Log.e(LCAT, "DUPLICATE DOWNLOAD FOR " + key);
				}
				cacheMap.put(key, ce);
				ArrayList<TiCacheCallback> callbacks = completionListeners.get(key);
				if (callbacks != null) {
					completionListeners.remove(key);
					File dataFile = getDataFile(ce.cacheKey);
					for (TiCacheCallback callback : callbacks) {
						try {
							callback.fileReady(dataFile);
						} catch (Throwable t) {
							Log.e(LCAT, "Error notifying read for " + key, t);
						}
					}
					callbacks.clear();
				}
			} else {
				error(key, null);
			}
		}
	}
	
	void error(String key, Throwable t) 
	{
		synchronized(cacheMap) {
			ArrayList<TiCacheCallback> callbacks = completionListeners.get(key);
			if (callbacks != null) {
				completionListeners.remove(key);
				for (TiCacheCallback callback : callbacks) {
					try {
						callback.error(t);
					} catch (Throwable t1) {
						Log.e(LCAT, "Error notifying error for " + key, t1);
					}
				}
				callbacks.clear();
			}			
		}
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
