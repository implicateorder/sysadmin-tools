#!/usr/sbin/dtrace -s

#pragma D option quiet
#pragma D option destructive

fbt::kmem_cache_alloc:entry 
{
	@alloc[args[0]->cache_name] = count();
}

fbt::kmem_cache_free:entry
{
	@free[args[0]->cache_name] = count();
}

tick-1sec
{
	system("clear");
	trunc(@alloc,20);
	trunc(@free,20);
	printf("Tracing...If you see more allocs than frees, there is a potential issue...\nCheck against the cache name that is suspect\n\n");
	printf("%-32s %-8s %-8s\n", "CACHE NAME", "ALLOCS", "FREES");
	printa("%-32s %-@8d %-@8d\n", @alloc, @free);

}

