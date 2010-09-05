/**
 * 
 */
package org.appcelerator.titanium.cache;

/**
 * @author dthorp
 *
 */
public class TiCacheManagerException extends Exception 
{

	private static final long serialVersionUID = 1L;

	public TiCacheManagerException(String detailMessage) 
	{
		super(detailMessage);
	}

	public TiCacheManagerException(Throwable throwable) {
		super(throwable);
	}

	public TiCacheManagerException(String detailMessage, Throwable throwable) {
		super(detailMessage, throwable);
	}
}
