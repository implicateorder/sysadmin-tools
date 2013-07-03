#!/usr/sbin/dtrace -qs

/* 
 * Based on Menno Lageman's DTrace scripts and helpful suggestions.
 * Jeff Savit, June 2011
 * Instruments ldom live migration times and efficiency
 */


unsigned long long total_uncompressed;
unsigned long long total_compressed;

BEGIN
{
        printf("Type CTRL-C to exit when migrations complete.\n");
	total_uncompressed = 0l;
	total_compressed = 0l;
}


/*
 * compression: Save uncompressed size and start timestamp.
 */

ldmd*:::mig-compress-start
{
        self->uncompressed_size = arg0;
	total_uncompressed = total_uncompressed + self->uncompressed_size;
        self->t0 = timestamp;
        /* printf("%s %s -- %d bytes at %Y\n",  probefunc, probename, self->uncompressed_size, walltimestamp); */
	@count[probefunc,probename] = count();
}


/*
 * compression: show amount saved and calculate the elapsed time.
 */

ldmd*:::mig-compress-done 
/self->t0/
{
        this->t1 = timestamp;
        this->compressed_size=arg0;
	total_compressed = total_compressed + this->compressed_size;
	this->saved = (self->uncompressed_size - this->compressed_size);
        /* printf("%s %s -- %d bytes reduced to %d saving %d took %d ms\n", probefunc, probename,
	    self->uncompressed_size, this->compressed_size, this->saved,
            (this->t1 - self->t0) / 1000000); */
	@count[probefunc,probename] = count();
	@sum_compressed[probefunc,probename] = sum(this->saved);
        @sum_compress_time[probefunc,probename] = sum((this->t1 - self->t0) / 1000000);
	@avg_compress_time[probefunc,probename] = avg((this->t1 - self->t0) / 1000000);
	@compress_saved[probename] = quantize(this->saved);
}


/*
 * decompression: Save uncompressed size and start timestamp.
 */

ldmd*::mig_decompress:mig-decompress-start 
{
        self->compressed_size = arg0;
	total_compressed = total_compressed + self->compressed_size;
        self->t0 = timestamp;
        /* printf("%s %s -- %d bytes at %Y \n", probefunc, probename, self->compressed_size, walltimestamp); */
	@count[probefunc,probename] = count();
}


/*
 * decompression: show amount saved and calculate the elapsed time.
 */

ldmd*::mig_decompress:mig-decompress-done
/self->t0/
{
        this->t1 = timestamp;
        this->decompressed_size=arg0;
	total_uncompressed = total_uncompressed + this->decompressed_size;
	this->saved = (this->decompressed_size - self->compressed_size);
        /* printf("%s %s -- %d bytes decompressed from %d saving %d took %d ms\n",
	    probefunc, probename,
	    this->decompressed_size, self->compressed_size, this->saved,
            (this->t1 - self->t0) / 1000000); */
	@count[probefunc,probename] = count();
	@sum_compressed[probefunc,probename] = sum(this->saved);
        @sum_compress_time[probefunc,probename] = sum((this->t1 - self->t0) / 1000000);
        @avg_compress_time[probefunc,probename] = avg((this->t1 - self->t0) / 1000000);
	@compress_saved[probename] = quantize(this->saved);
}


/*
 * migration memory transfer pass start and end
 */

ldmd*:::mig-pass-start
{
        self->t0 = timestamp;
	self->pass = arg0;
        printf("%s %s -- pass %d at %Y\n", probefunc, probename, self->pass, walltimestamp);
	@count[probefunc,probename] = count();
}

ldmd*:::mig-pass-done
{
        this->t1 = timestamp;
        printf("%s %s -- pass %d at %Y took %d \n", probefunc, probename, self->pass, walltimestamp,
            (this->t1 - self->t0) / 1000000);
	@count[probefunc,probename] = count();
        @sum_pass_time[probefunc,probename,self->pass] = sum((this->t1 - self->t0) / 1000000);
}


/*
 * migration transfer start and end
 */

ldmd*:::mig-transfer-start  
{
        self->t0 = timestamp;
        printf("%s %s -- at %Y\n", probefunc, probename, walltimestamp);
	@count[probefunc,probename] = count();
}

ldmd*:::mig-transfer-done
{
        this->t1 = timestamp;
        printf("%s %s -- at %Y took %d \n", probefunc, probename, walltimestamp,
            (this->t1 - self->t0) / 1000000);
	@count[probefunc,probename] = count();
        @sum_mig_transfer_time[probefunc,probename] = sum((this->t1 - self->t0) / 1000000);
}

END
{
        printf("\n\nProbe Counts\n");
        printa(@count);
        printf("\n\n(De)compressed bytes by probe\n");
        printa(@sum_compressed);
	printf("\n\nTotal bytes uncompressed = %d - total compressed = %d - percent reduction %d", 
		total_uncompressed, total_compressed, (100*(total_uncompressed-total_compressed)/total_uncompressed) );
        printf("\n\nTotal (de)compression time\n");
        printa(@sum_compress_time);
        printf("\n\nAverage (de)compression time\n");
	printa(@avg_compress_time);
	printf("\n\nCompression savings\n");
	printa(@compress_saved);
        printf("\n\nTime by pass (source host only)\n");
        printa(@sum_pass_time);
        printf("\n\nTransfer Time\n");
	printa(@sum_mig_transfer_time);
}
