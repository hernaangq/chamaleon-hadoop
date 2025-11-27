set -ex
#Test automation - search
#vaultx_linux_86

#1. File generation
#k = 30

mkdir -p results
filename="./results/results.csv"

#create or replace file
touch $filename

#Empty preexisting file
> $filename

./vaultx_linux_x86 -t 32 -i 1 -m 2048 -k 30 -g data-16GB.tmp -f data-16GB.bin

testType="hashSearch"

for diff in "3 4"; do

    # Run vaultx and collect its metrics
    ./vaultx_linux_x86 -k 30 -f data-16GB.bin -s 1000 -q $diff -d true 2>&1| \
    awk -v diffLvl="$diff" -v searches="1000" -v kval="30" -v testtype="$testType" '
    /Actual file size on disk/    { filesize=$7 }
    /Search Summary:/ {
        match($0,/found_queries=([0-9]+)/,m); found=m[1]
        match($0,/notfound=([0-9]+)/,n); notfound=n[1]
    }
    /total_time=/ {
        match($0,/total_time=([0-9.]+)/,t); total_time=t[1]
        match($0,/avg_ms=([0-9.]+)/,m); avg_ms=m[1]
        match($0,/searches\/sec=([0-9.]+)/,r); throughput=r[1]
    }
    /avg_seeks_per_search=/ {
        match($0,/avg_seeks_per_search=([0-9.]+)/,s); avg_seeks=s[1]
    }
    END {
        avg_data_read = (filesize > 0 && searches > 0) ? filesize / searches : 0
        printf "%s,%s,%s,%s,%.0f,%s,%s,%s,%s,%s,%s\n",
            kval, diffLvl, searches, avg_seeks, avg_data_read,
            total_time, avg_ms, throughput, found, notfound, testtype
    }' >> "$filename"

done
