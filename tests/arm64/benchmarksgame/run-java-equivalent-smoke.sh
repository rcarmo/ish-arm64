#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

ISH_BIN="${ISH_BIN:-$PROJECT_DIR/build-arm64-linux/ish}"
ROOTFS="${ROOTFS:-$PROJECT_DIR/alpine-arm64-fakefs}"
TIMEOUT_S="${TIMEOUT_S:-1200}"
REPORT_DIR="${REPORT_DIR:-/workspace/tmp}"
STAMP="$(date +%Y%m%d-%H%M%S)"
REPORT="$REPORT_DIR/benchmarksgame-java-equivalent-smoke-$STAMP.md"
GUEST_WORK="/tmp/benchmarksgame-java-equivalent-smoke"
HOST_TMP="$(mktemp -d)"

BENCHMARKS=(binarytrees fannkuchredux fasta knucleotide mandelbrot nbody pidigits regexredux revcomp spectralnorm)

cleanup() { rm -rf "$HOST_TMP"; }
trap cleanup EXIT
mkdir -p "$REPORT_DIR"

log() { printf '>>> %s\n' "$*"; }

guest_capture() {
    timeout "$TIMEOUT_S" "$ISH_BIN" -f "$ROOTFS" /bin/sh -c "export PATH=/usr/lib/jvm/java-21-openjdk/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin; { $1; }; rc=\$?; printf '\n__ISH_STATUS:%s\n' \"\$rc\""
}

push_tree() {
    local src="$1" dst="$2"
    tar -C "$src" -cf - . | timeout "$TIMEOUT_S" "$ISH_BIN" -f "$ROOTFS" /bin/sh -c "rm -rf '$dst' && mkdir -p '$dst' && tar -xf - -C '$dst'"
}

ensure_guest_packages() {
    log "Ensuring OpenJDK in guest"
    local out="$HOST_TMP/ensure.log"
    guest_capture "apk add --no-cache openjdk21-jdk >/dev/null" >"$out" 2>&1
    grep -q '^__ISH_STATUS:0$' "$out"
}

prepare_sources() {
    local src="$HOST_TMP/src"
    mkdir -p "$src"
    cat >"$src/BenchmarkSmoke.java" <<'JAVA'
import java.io.*;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.regex.*;

public final class BenchmarkSmoke {
    static final byte[] ALU = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG".getBytes(StandardCharsets.US_ASCII);
    static final byte[] IUB = "acgtBDHKMNRSVWY".getBytes(StandardCharsets.US_ASCII);
    static final int[] COMP = new int[256];
    static { Arrays.fill(COMP, 'N'); String a="ACGTUMRWSYKVHDBNacgtumrwsykvhdbn"; String b="TGCAAKYWSRMBDHVNtgcaakywsrmbdhvn"; for (int i=0;i<a.length();i++) COMP[a.charAt(i)] = b.charAt(i); }

    public static void main(String[] args) throws Exception {
        String name = args.length == 0 ? "" : args[0];
        int n = args.length > 1 ? Integer.parseInt(args[1]) : 100;
        switch (name) {
            case "binarytrees": binarytrees(n); break;
            case "fannkuchredux": fannkuchredux(n); break;
            case "fasta": fasta(n); break;
            case "knucleotide": knucleotide(); break;
            case "mandelbrot": mandelbrot(n); break;
            case "nbody": nbody(n); break;
            case "pidigits": pidigits(n); break;
            case "regexredux": regexredux(); break;
            case "revcomp": revcomp(); break;
            case "spectralnorm": spectralnorm(n); break;
            default: throw new IllegalArgumentException("unknown benchmark: " + name);
        }
    }

    static final class Tree { Tree l, r; Tree(int d) { if (d > 0) { l = new Tree(d - 1); r = new Tree(d - 1); } } int check() { return l == null ? 1 : 1 + l.check() + r.check(); } }
    static void binarytrees(int n) { int min = 4, max = Math.max(min + 2, n); int stretch = max + 1; System.out.println("stretch tree of depth " + stretch + "\t check: " + new Tree(stretch).check()); Tree longLived = new Tree(max); for (int d = min; d <= max; d += 2) { int it = 1 << (max - d + min); int c = 0; for (int i = 0; i < it; i++) c += new Tree(d).check(); System.out.println(it + "\t trees of depth " + d + "\t check: " + c); } System.out.println("long lived tree of depth " + max + "\t check: " + longLived.check()); }

    static void fannkuchredux(int n) { int[] p = new int[n], pp = new int[n], count = new int[n]; for (int i=0;i<n;i++) p[i]=i; int max=0, chk=0, r=n, perm=0; while (true) { while (r != 1) { count[r-1] = r; r--; } System.arraycopy(p,0,pp,0,n); int flips=0; while (pp[0] != 0) { int k=pp[0]; for (int i=0,j=k;i<j;i++,j--) { int t=pp[i]; pp[i]=pp[j]; pp[j]=t; } flips++; } max = Math.max(max, flips); chk += (perm % 2 == 0) ? flips : -flips; while (true) { if (r == n) { System.out.println(chk); System.out.println("Pfannkuchen("+n+") = "+max); return; } int first = p[0]; for (int i=0;i<r;i++) p[i]=p[i+1]; p[r]=first; count[r]--; if (count[r] > 0) break; r++; } perm++; } }

    static void fasta(int n) throws IOException { BufferedOutputStream out = new BufferedOutputStream(System.out); out.write(">THREE\n".getBytes(StandardCharsets.US_ASCII)); byte[] seq = ALU; for (int i=0;i<n;i+=60) { int len=Math.min(60,n-i); for (int j=0;j<len;j++) out.write(seq[(i+j)%seq.length]); out.write('\n'); } out.flush(); }

    static String stdin() throws IOException { return new String(System.in.readAllBytes(), StandardCharsets.US_ASCII); }
    static void knucleotide() throws IOException { String s = stdin().replaceAll("(?m)^>.*$", "").replaceAll("\\s+", "").toUpperCase(Locale.ROOT); for (int k: new int[]{1,2}) { Map<String,Integer> m = new HashMap<>(); for (int i=0;i+k<=s.length();i++) m.merge(s.substring(i,i+k),1,Integer::sum); int total = Math.max(1, s.length()-k+1); m.entrySet().stream().sorted((a,b)->{int c=b.getValue()-a.getValue(); return c!=0?c:a.getKey().compareTo(b.getKey());}).forEach(e -> System.out.printf(Locale.ROOT, "%s %.3f%n", e.getKey(), 100.0*e.getValue()/total)); System.out.println(); } for (String f: new String[]{"GGT", "GGTA", "GGTATT"}) { int c=0; for (int i=0;i+f.length()<=s.length();i++) if (s.regionMatches(i,f,0,f.length())) c++; System.out.println(c+"\t"+f); } }

    static void mandelbrot(int n) throws IOException { BufferedOutputStream out = new BufferedOutputStream(System.out); out.write(("P4\n"+n+" "+n+"\n").getBytes(StandardCharsets.US_ASCII)); for (int y=0;y<n;y++) { int bits=0, bit=0; double ci=2.0*y/n-1.0; for (int x=0;x<n;x++) { double cr=2.0*x/n-1.5, zr=0, zi=0; int i=0; while (i<50 && zr*zr+zi*zi<=4.0) { double nzr=zr*zr-zi*zi+cr; zi=2*zr*zi+ci; zr=nzr; i++; } bits=(bits<<1)|(i==50?1:0); if (++bit==8) { out.write(bits); bits=0; bit=0; } } if (bit!=0) out.write(bits << (8-bit)); } out.flush(); }

    static final class Body { double x,y,z,vx,vy,vz,m; Body(double x,double y,double z,double vx,double vy,double vz,double m){this.x=x;this.y=y;this.z=z;this.vx=vx;this.vy=vy;this.vz=vz;this.m=m;} }
    static void nbody(int n) { double pi=Math.PI, days=365.24, solar=4*pi*pi; Body[] b={new Body(0,0,0,0,0,0,solar),new Body(4.84143144246472090e+00,-1.16032004402742839e+00,-1.03622044471123109e-01,1.66007664274403694e-03*days,7.69901118419740425e-03*days,-6.90460016972063023e-05*days,9.54791938424326609e-04*solar),new Body(8.34336671824457987e+00,4.12479856412430479e+00,-4.03523417114321381e-01,-2.76742510726862411e-03*days,4.99852801234917238e-03*days,2.30417297573763929e-05*days,2.85885980666130812e-04*solar),new Body(1.28943695621391310e+01,-1.51111514016986312e+01,-2.23307578892655734e-01,2.96460137564761618e-03*days,2.37847173959480950e-03*days,-2.96589568540237556e-05*days,4.36624404335156298e-05*solar),new Body(1.53796971148509165e+01,-2.59193146099879641e+01,1.79258772950371181e-01,2.68067772490389322e-03*days,1.62824170038242295e-03*days,-9.51592254519715870e-05*days,5.15138902046611451e-05*solar)}; for(Body p:b){b[0].vx-=p.vx*p.m/solar;b[0].vy-=p.vy*p.m/solar;b[0].vz-=p.vz*p.m/solar;} energy(b); for(int i=0;i<n;i++) advance(b,0.01); energy(b); }
    static void advance(Body[] b,double dt){for(int i=0;i<b.length;i++)for(int j=i+1;j<b.length;j++){double dx=b[i].x-b[j].x,dy=b[i].y-b[j].y,dz=b[i].z-b[j].z,d2=dx*dx+dy*dy+dz*dz,mag=dt/(d2*Math.sqrt(d2));b[i].vx-=dx*b[j].m*mag;b[i].vy-=dy*b[j].m*mag;b[i].vz-=dz*b[j].m*mag;b[j].vx+=dx*b[i].m*mag;b[j].vy+=dy*b[i].m*mag;b[j].vz+=dz*b[i].m*mag;}for(Body p:b){p.x+=dt*p.vx;p.y+=dt*p.vy;p.z+=dt*p.vz;}}
    static void energy(Body[] b){double e=0;for(int i=0;i<b.length;i++){Body p=b[i];e+=0.5*p.m*(p.vx*p.vx+p.vy*p.vy+p.vz*p.vz);for(int j=i+1;j<b.length;j++){double dx=p.x-b[j].x,dy=p.y-b[j].y,dz=p.z-b[j].z;e-=p.m*b[j].m/Math.sqrt(dx*dx+dy*dy+dz*dz);}}System.out.printf(Locale.ROOT,"%.9f%n",e);}

    static void pidigits(int n) { BigInteger q=BigInteger.ONE,r=BigInteger.ZERO,t=BigInteger.ONE,k=BigInteger.ONE,n1=BigInteger.valueOf(3),l=BigInteger.valueOf(3); int i=0; while(i<n){ if(q.shiftLeft(2).add(r).subtract(t).compareTo(n1.multiply(t))<0){ System.out.print(n1); if(++i%10==0) System.out.println("\t:"+i); BigInteger nr=BigInteger.TEN.multiply(r.subtract(n1.multiply(t))); n1=BigInteger.TEN.multiply(q.multiply(BigInteger.valueOf(3)).add(r)).divide(t).subtract(BigInteger.TEN.multiply(n1)); q=q.multiply(BigInteger.TEN); r=nr; } else { BigInteger nr=q.shiftLeft(1).add(r).multiply(l); BigInteger nn=q.multiply(k.multiply(BigInteger.valueOf(7))).add(BigInteger.valueOf(2)).add(r.multiply(l)).divide(t.multiply(l)); q=q.multiply(k); t=t.multiply(l); l=l.add(BigInteger.valueOf(2)); k=k.add(BigInteger.ONE); n1=nn; r=nr; } } if(i%10!=0) System.out.println("\t:"+i); }

    static void regexredux() throws IOException { String input=stdin(); int initial=input.length(); String seq=input.replaceAll(">.*\\n|\\n", ""); String[] pats={"agggtaaa|tttaccct","[cgt]gggtaaa|tttaccc[acg]","a[act]ggtaaa|tttacc[agt]t","ag[act]gtaaa|tttac[agt]ct","agg[act]taaa|ttta[agt]cct","aggg[acg]aaa|ttt[cgt]ccct","agggt[cgt]aa|tt[acg]accct","agggta[cgt]a|t[acg]taccct","agggtaa[cgt]|[acg]ttaccct"}; for(String p:pats){Matcher m=Pattern.compile(p,Pattern.CASE_INSENSITIVE).matcher(seq); int c=0; while(m.find()) c++; System.out.println(p+" "+c);} String out=seq.replaceAll("B","(c|g|t)").replaceAll("D","(a|g|t)").replaceAll("H","(a|c|t)").replaceAll("K","(g|t)").replaceAll("M","(a|c)").replaceAll("N","(a|c|g|t)").replaceAll("R","(a|g)").replaceAll("S","(c|g)").replaceAll("V","(a|c|g)").replaceAll("W","(a|t)").replaceAll("Y","(c|t)"); System.out.println(); System.out.println(initial); System.out.println(seq.length()); System.out.println(out.length()); }

    static void revcomp() throws IOException { String input=stdin(); BufferedOutputStream out=new BufferedOutputStream(System.out); for(String block: input.split("(?=>)")){ if(block.isEmpty()) continue; int nl=block.indexOf('\n'); if(nl<0) continue; out.write(block.substring(0,nl+1).getBytes(StandardCharsets.US_ASCII)); String s=block.substring(nl+1).replaceAll("\\s+", ""); for(int i=s.length(); i>0; ){ int start=Math.max(0,i-60); for(int j=i-1;j>=start;j--) out.write(COMP[s.charAt(j)&255]); out.write('\n'); i=start; } } out.flush(); }

    static void spectralnorm(int n) { double[] u=new double[n], v=new double[n], w=new double[n]; Arrays.fill(u,1.0); for(int i=0;i<10;i++){multAtAv(u,v,w);multAtAv(v,u,w);} double vbv=0,vv=0; for(int i=0;i<n;i++){vbv+=u[i]*v[i];vv+=v[i]*v[i];} System.out.printf(Locale.ROOT,"%.9f%n",Math.sqrt(vbv/vv)); }
    static double A(int i,int j){int ij=i+j; return 1.0/((ij*(ij+1)/2)+i+1);} static void multAv(double[] v,double[] out){for(int i=0;i<v.length;i++){double s=0;for(int j=0;j<v.length;j++)s+=A(i,j)*v[j];out[i]=s;}} static void multAtv(double[] v,double[] out){for(int i=0;i<v.length;i++){double s=0;for(int j=0;j<v.length;j++)s+=A(j,i)*v[j];out[i]=s;}} static void multAtAv(double[] v,double[] out,double[] tmp){multAv(v,tmp);multAtv(tmp,out);}
}
JAVA
}

prepare_guest() {
    push_tree "$HOST_TMP/src" "$GUEST_WORK/src"
    timeout "$TIMEOUT_S" "$ISH_BIN" -f "$ROOTFS" /bin/sh -c "mkdir -p '$GUEST_WORK/out'; cat > '$GUEST_WORK/run.sh'" <<'GUEST'
set -eu
export PATH=/usr/lib/jvm/java-21-openjdk/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
cd /tmp/benchmarksgame-java-equivalent-smoke
mkdir -p out classes
JAVA_OPTS='-Xmx128m -Xms16m'
echo "__JAVA_VERSION_BEGIN"
# Keep HotSpot fatal-error spew bounded if the VM cannot start.
(timeout 20 sh -c "java $JAVA_OPTS -version 2>&1 | head -80") || true
echo "__JAVA_VERSION_END"
timeout 20 sh -c "java $JAVA_OPTS -version 2>&1 | head -20 > /tmp/java-version-ok.log" || true
if grep -q 'OpenJDK\|Java VM' /tmp/java-version-ok.log && ! grep -q 'Internal Error\|fatal error' /tmp/java-version-ok.log; then
    echo "__JAVA_VERSION_OK"
fi
if ! grep -q 'OpenJDK\|Java VM' /tmp/java-version-ok.log || grep -q 'Internal Error\|fatal error' /tmp/java-version-ok.log; then
    echo "__JAVA_STARTUP_BLOCKED"
    cat /tmp/java-version-ok.log
    exit 1
fi
javac -d classes src/BenchmarkSmoke.java
echo "__JAVA_BUILD:PASS"
python3 - <<'PY' > input.fa
print('>THREE')
seq = 'ACGT' * 2500
for i in range(0, len(seq), 60):
    print(seq[i:i+60])
PY
run_arg() {
    name="$1"; arg="$2"
    echo "__BG_BEGIN:$name"
    /usr/bin/time -f "__BG_TIME:$name:%e" java $JAVA_OPTS -cp classes BenchmarkSmoke "$name" "$arg" > "out/$name.out"
    bytes=$(wc -c < "out/$name.out"); lines=$(wc -l < "out/$name.out")
    cksum=$(cksum "out/$name.out" | awk '{print $1":"$2}')
    echo "__BG_RESULT:$name:PASS:$bytes:$lines:$cksum"
}
run_stdin() {
    name="$1"
    echo "__BG_BEGIN:$name"
    /usr/bin/time -f "__BG_TIME:$name:%e" java $JAVA_OPTS -cp classes BenchmarkSmoke "$name" < input.fa > "out/$name.out"
    bytes=$(wc -c < "out/$name.out"); lines=$(wc -l < "out/$name.out")
    cksum=$(cksum "out/$name.out" | awk '{print $1":"$2}')
    echo "__BG_RESULT:$name:PASS:$bytes:$lines:$cksum"
}
run_arg binarytrees 7
run_arg fannkuchredux 7
run_arg fasta 1000
run_stdin knucleotide
run_arg mandelbrot 100
run_arg nbody 1000
run_arg pidigits 100
run_stdin regexredux
run_stdin revcomp
run_arg spectralnorm 100
echo "__BG_ALL_DONE"
GUEST
}

run_guest() {
    log "Running Java-equivalent Benchmarks Game smoke in guest"
    guest_capture "sh '$GUEST_WORK/run.sh'" >"$HOST_TMP/guest.log" 2>&1 || true
}

write_report() {
    local total_count pass_count build_status java_status
    total_count=${#BENCHMARKS[@]}
    pass_count=$(grep -c '^__BG_RESULT:.*:PASS:' "$HOST_TMP/guest.log" || true)
    build_status=$(grep -q '^__JAVA_BUILD:PASS$' "$HOST_TMP/guest.log" && echo PASS || echo FAIL)
    java_status=$(grep -q '^__JAVA_VERSION_OK$' "$HOST_TMP/guest.log" && echo PASS || echo FAIL)
    {
        echo "# Benchmarks Game Java-equivalent smoke report"
        echo
        echo "- Timestamp: $(date -Is)"
        echo "- ish binary: $ISH_BIN"
        echo "- rootfs: $ROOTFS"
        echo "- timeout: ${TIMEOUT_S}s"
        echo "- guest workdir: $GUEST_WORK"
        echo "- Source status: current Benchmarks Game pages do not advertise a Java language row; this runner uses local Java equivalents."
        echo "- Java startup: $java_status"
        echo "- Build result: $build_status"
        echo "- Result: $pass_count / $total_count passing"
        echo
        echo "## Results"
        echo
        echo "| Benchmark | Status | Bytes | Lines | CRC:Size | Time (s) |"
        echo "|---|---:|---:|---:|---|---:|"
        for bench in "${BENCHMARKS[@]}"; do
            result=$(grep "^__BG_RESULT:$bench:" "$HOST_TMP/guest.log" | tail -1 || true)
            time_line=$(grep "^__BG_TIME:$bench:" "$HOST_TMP/guest.log" | tail -1 || true)
            elapsed="${time_line##*:}"
            if [ -n "$result" ]; then
                IFS=: read -r _ name status bytes lines checksum <<<"$result"
                echo "| $bench | $status | $bytes | $lines | $checksum | $elapsed |"
            else
                echo "| $bench | BLOCKED | 0 | 0 | — | — |"
            fi
        done
        echo
        echo "## Raw guest log tail"
        echo
        echo '```text'
        tail -220 "$HOST_TMP/guest.log" | sed '/^__ISH_STATUS:/d'
        echo '```'
    } >"$REPORT"
    echo "report: $REPORT"
    [ "$java_status" = PASS ] && [ "$build_status" = PASS ] && [ "$pass_count" -eq "$total_count" ]
}

ensure_guest_packages
prepare_sources
prepare_guest
run_guest
write_report
