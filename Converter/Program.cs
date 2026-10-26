using System.IO.Compression;
using System.Text.Json;
using System.Security.Cryptography;
using System.Text;

record Tile(int x,int y,int z,int id);
record Static(int x,int y,int z,int id,int hue);
record TileInfo(string name,ulong flags,int height);
record World(int schema,string facet,string provenance,int originX,int originY,int width,int height,double elevationScale,Tile[] terrain,Static[] statics,string mapSha256,Dictionary<int,TileInfo>? landData=null,Dictionary<int,TileInfo>? staticData=null,string? tiledataSha256=null);

static partial class Program {
 static readonly JsonSerializerOptions Json = new(){WriteIndented=true};
 static void Main(string[] args) {
  try {
   if(args.Length==0) throw new ArgumentException("Commands: fixture DIR | test DIR | convert DIR OUT [x y width height mapHeight]");
   if(args[0]=="atlas") { ExportAtlas(args); return; }
   if(args[0]=="fixture") { Fixture(args[1]); return; }
   if(args[0]=="test") { Tests(args[1]); return; }
   if(args[0]=="reference") { ArtReference.Export(args[1],args[2],args[3]); return; }
   if(args[0]=="item-art") { ArtReference.Export(args[1],"",args[2],args[3].Split(',').Select(int.Parse).ToArray()); return; }
   if(args[0]=="gump-art") { GumpArt.Export(args[1],args[2],args[3].Split(',').Select(int.Parse).ToArray()); return; }
   if(args[0]!="convert" || args.Length<3) throw new ArgumentException("convert DIR OUT [x y width height mapHeight]");
   int[] p={1408,1664,48,48,4096}; for(int i=3;i<args.Length;i++) p[i-3]=int.Parse(args[i]);
   var w=Convert(args[1],p[0],p[1],p[2],p[3],p[4]);
   Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(args[2]))!);
   File.WriteAllText(args[2],JsonSerializer.Serialize(w,Json));
   Console.WriteLine($"{w.provenance}: {w.terrain.Length} terrain samples, {w.statics.Length} statics -> {args[2]}");
  } catch(Exception e) {Console.Error.WriteLine(e.Message); Environment.ExitCode=1;}
 }
 static BinaryReader Read(string path)=>new(File.Open(path,FileMode.Open,FileAccess.Read,FileShare.Read));
 static void Range(long offset,long size,long length) {if(offset<0||size<0||offset>length-size) throw new InvalidDataException("Truncated or invalid file range");}
 static World Convert(string dir,int ox,int oy,int width,int height,int mapHeight,bool fingerprint=true) {
  if(mapHeight<=0||mapHeight%8!=0||ox<0||oy<0||width<2||height<2||width>256||height>256||oy+height>mapHeight) throw new ArgumentException("Invalid region (2..256) or map height");
  // Never silently substitute Felucca for Trammel.
  string map=Path.Combine(dir,"map1.mul"),uop=Path.Combine(dir,"map1LegacyMUL.uop");
  bool packed=!File.Exists(map); if(packed) map=uop;
  using var mr=Read(map); var archive=packed?new Uop(mr):null;
  using var idx=Read(Path.Combine(dir,"staidx1.mul")); using var sta=Read(Path.Combine(dir,"statics1.mul"));
  if(File.Exists(Path.Combine(dir,"verdata.mul"))) throw new NotSupportedException("Legacy verdata overlay is not supported");
  using var landPatch=new Patch(dir,false); using var staticPatch=new Patch(dir,true);
  int blocksY=mapHeight/8; var tiles=new List<Tile>(); var statics=new List<Static>();
  for(int bx=ox/8;bx<=(ox+width-1)/8;bx++) for(int by=oy/8;by<=(oy+height-1)/8;by++) {
   int block=checked(bx*blocksY+by); byte[] data;
   if(landPatch.blocks.TryGetValue(block,out int patchBlock)) {var pr=landPatch.data!;long pos=(long)patchBlock*196;Range(pos,196,pr.BaseStream.Length);pr.BaseStream.Position=pos;data=pr.ReadBytes(196);}
   else if(archive!=null) {var chunk=archive.Chunk(block/4096); int pos=(block%4096)*196; Range(pos,196,chunk.Length); data=chunk.AsSpan(pos,196).ToArray();}
   else {long pos=(long)block*196; Range(pos,196,mr.BaseStream.Length); mr.BaseStream.Position=pos; data=mr.ReadBytes(196);}
   using var br=new BinaryReader(new MemoryStream(data)); br.ReadUInt32();
   for(int ly=0;ly<8;ly++) for(int lx=0;lx<8;lx++) {int id=br.ReadUInt16(),z=br.ReadSByte(),x=bx*8+lx,y=by*8+ly; if(x>=ox&&x<ox+width&&y>=oy&&y<oy+height) tiles.Add(new(x,y,z,id));}
   bool patched=staticPatch.blocks.TryGetValue(block,out int si);var ir=patched?staticPatch.index!:idx;var sr=patched?staticPatch.data!:sta;
   long ip=(long)(patched?si:block)*12; Range(ip,12,ir.BaseStream.Length); ir.BaseStream.Position=ip;
   int off=ir.ReadInt32(),len=ir.ReadInt32(); ir.ReadInt32();
   if(off==-1||len==0) continue;
   if(len%7!=0) throw new InvalidDataException("Static length is not divisible by 7");
   Range(off,len,sr.BaseStream.Length); sr.BaseStream.Position=off;
   for(int n=0;n<len/7;n++) {int id=sr.ReadUInt16(),lx=sr.ReadByte(),ly=sr.ReadByte(),z=sr.ReadSByte(),hue=sr.ReadUInt16(); if(lx>7||ly>7) throw new InvalidDataException("Invalid static local coordinate"); int x=bx*8+lx,y=by*8+ly; if(x>=ox&&x<ox+width&&y>=oy&&y<oy+height) statics.Add(new(x,y,z,id,hue));}
  }
  mr.BaseStream.Position=0; string sha=fingerprint?System.Convert.ToHexString(SHA256.HashData(mr.BaseStream)):"";
  Dictionary<int,TileInfo>? land=null,objects=null;string? tileSha=null;
  string tilePath=Path.Combine(dir,"tiledata.mul");
  if(File.Exists(tilePath)) {
   using var td=Read(tilePath);
   land=tiles.Select(t=>t.id).Distinct().ToDictionary(id=>id,id=>ReadTileInfo(td,id,false));
   objects=statics.Select(t=>t.id).Distinct().ToDictionary(id=>id,id=>ReadTileInfo(td,id,true));
   td.BaseStream.Position=0;tileSha=fingerprint?System.Convert.ToHexString(SHA256.HashData(td.BaseStream)):null;
  }
  return new(1,"Trammel (map1)",File.Exists(Path.Combine(dir,"SYNTHETIC.txt"))?"SYNTHETIC — invented terrain; NOT Britain geography":$"LOCAL TRAMMEL — base + local diffs ({landPatch.blocks.Count}/{staticPatch.blocks.Count})",ox,oy,width,height,0.2,tiles.ToArray(),statics.ToArray(),sha,land,objects,tileSha);
 }
 static TileInfo ReadTileInfo(BinaryReader reader,int id,bool statics) {
  long length=reader.BaseStream.Length;
  bool modern=length>=3188736;
  int flags=modern?8:4,landRecord=flags+22,staticRecord=flags+33;
  long landSize=512L*(4+32*landRecord);
  if(length<landSize || (length-landSize)%(4+32*staticRecord)!=0) throw new InvalidDataException("Unsupported/truncated tiledata layout");
  int record=statics?staticRecord:landRecord;
  long offset=(statics?landSize:0)+(long)(id/32)*(4+32*record)+4+(id%32)*record;
  if(id<0||(!statics&&id>=16384))throw new InvalidDataException("Invalid tiledata ID");
  Range(offset,record,length);reader.BaseStream.Position=offset;
  ulong value=modern?reader.ReadUInt64():reader.ReadUInt32();int height=0;
  if(statics){reader.BaseStream.Position+=12;height=reader.ReadByte();}else reader.ReadUInt16();
  string name=Encoding.ASCII.GetString(reader.ReadBytes(20)).TrimEnd('\0');
  return new(name,value,height);
 }
 sealed class Patch : IDisposable {
  public readonly Dictionary<int,int> blocks=new(); public readonly BinaryReader? data,index;
  public Patch(string dir,bool statics) {
   string[] names=statics?new[]{"stadifl1.mul","stadif1.mul","stadifi1.mul"}:new[]{"mapdifl1.mul","mapdif1.mul"};
   int present=names.Count(n=>File.Exists(Path.Combine(dir,n)));if(present==0)return;if(present!=names.Length)throw new NotSupportedException("Incomplete patch set: "+string.Join(", ",names));
   using var list=Read(Path.Combine(dir,names[0]));if(list.BaseStream.Length%4!=0)throw new InvalidDataException("Bad diff list length");
   int n=0;while(list.BaseStream.Position<list.BaseStream.Length){int block=list.ReadInt32();if(block<0)throw new InvalidDataException("Bad diff block ID");blocks[block]=n++;}
   data=Read(Path.Combine(dir,names[1]));if(statics)index=Read(Path.Combine(dir,names[2]));
  }
  public void Dispose(){data?.Dispose();index?.Dispose();}
 }
 // UOP uses lookup3/hashlittle2 with filename ASCII bytes; high 32 bits are b.
 internal static ulong Hash(string s) {
  unchecked {
   uint a=0xdeadbeef+(uint)s.Length,b=a,c=a; int i=0;
   uint R(uint x,int k)=>(x<<k)|(x>>(32-k));
   uint Word(int j)=>(uint)(s[j]|s[j+1]<<8|s[j+2]<<16|s[j+3]<<24);
   while(s.Length-i>12) {a+=Word(i);b+=Word(i+4);c+=Word(i+8);a-=c;a^=R(c,4);c+=b;b-=a;b^=R(a,6);a+=c;c-=b;c^=R(b,8);b+=a;a-=c;a^=R(c,16);c+=b;b-=a;b^=R(a,19);a+=c;c-=b;c^=R(b,4);b+=a;i+=12;}
   int left=s.Length-i; for(int n=0;n<left;n++){uint v=(uint)s[i+n]<<((n%4)*8);if(n<4)a+=v;else if(n<8)b+=v;else c+=v;}
   if(left>0){c^=b;c-=R(b,14);a^=c;a-=R(c,11);b^=a;b-=R(a,25);c^=b;c-=R(b,16);a^=c;a-=R(c,4);b^=a;b-=R(a,14);c^=b;c-=R(b,24);}
   return ((ulong)b<<32)|c;
  }
 }
 sealed class Uop {
  readonly BinaryReader r; readonly Dictionary<ulong,(long off,int packed,int raw,ushort flag)> entries=new(); readonly Dictionary<int,byte[]> cache=new();
  public Uop(BinaryReader reader) {
   r=reader; if(r.ReadUInt32()!=0x0050594d) throw new InvalidDataException("Bad UOP signature");
   r.ReadUInt32();r.ReadUInt32();long next=r.ReadInt64();r.ReadUInt32();r.ReadUInt32();var seen=new HashSet<long>();
   while(next!=0){if(!seen.Add(next))throw new InvalidDataException("UOP directory cycle");Range(next,12,r.BaseStream.Length);r.BaseStream.Position=next;int count=r.ReadInt32();next=r.ReadInt64();if(count<0||count>100000)throw new InvalidDataException("Bad UOP count");Range(r.BaseStream.Position,(long)count*34,r.BaseStream.Length);
    for(int i=0;i<count;i++){long off=r.ReadInt64();int header=r.ReadInt32(),packed=r.ReadInt32(),raw=r.ReadInt32();ulong hash=r.ReadUInt64();r.ReadUInt32();ushort flag=r.ReadUInt16();if(off==0)continue;if(header<0||raw<0||raw>4096*196||flag>1)throw new InvalidDataException("Unsupported UOP entry/compression");Range(off,(long)header+packed,r.BaseStream.Length);entries.Add(hash,(off+header,packed,raw,flag));}
   }
  }
  public byte[] Chunk(int n) {
   if(cache.TryGetValue(n,out var found)) return found;
   if(!entries.TryGetValue(Hash($"build/map1legacymul/{n:D8}.dat"),out var e))throw new InvalidDataException("UOP map chunk missing: "+n);
   r.BaseStream.Position=e.off;byte[] bytes=r.ReadBytes(e.packed);
   if(e.flag==1){using var z=new ZLibStream(new MemoryStream(bytes),CompressionMode.Decompress);byte[] output=new byte[e.raw];z.ReadExactly(output);if(z.ReadByte()!=-1)throw new InvalidDataException("Oversize UOP payload");bytes=output;}
   if(bytes.Length!=e.raw)throw new InvalidDataException("UOP raw length mismatch");cache[n]=bytes;return bytes;
  }
 }
 static void Fixture(string dir) {
  Directory.CreateDirectory(dir);
  if(!File.Exists(Path.Combine(dir,"SYNTHETIC.txt")) && Directory.EnumerateFiles(dir).Any()) throw new IOException("Refusing to overwrite a non-fixture directory");
  File.WriteAllText(Path.Combine(dir,"SYNTHETIC.txt"),"Invented test grid at Britain-area coordinates, not a reconstruction. No game assets.");
  using var map=new BinaryWriter(File.Create(Path.Combine(dir,"map1.mul")));using var idx=new BinaryWriter(File.Create(Path.Combine(dir,"staidx1.mul")));using var sta=new BinaryWriter(File.Create(Path.Combine(dir,"statics1.mul")));
  // Sparse files retain real Britannia block indexing, 4096 tile height.
  for(int bx=176;bx<182;bx++)for(int by=208;by<214;by++){
   int block=bx*512+by;map.BaseStream.Position=(long)block*196;map.Write(0u);
   for(int ly=0;ly<8;ly++)for(int lx=0;lx<8;lx++){int x=bx*8+lx-1408,y=by*8+ly-1664;map.Write((ushort)(x>35?2:(x%12<3||y%12<3?1:0)));map.Write((sbyte)(x>35?-5:(x+y)/12));}
   idx.BaseStream.Position=(long)block*12;idx.Write((int)sta.BaseStream.Position);idx.Write(14);idx.Write(0);
   for(int k=0;k<2;k++){sta.Write((ushort)(100+k));sta.Write((byte)(k+3));sta.Write((byte)4);sta.Write((sbyte)(k==0?8:-3));sta.Write((ushort)(k*17));}
  }
 }
 static void Tests(string dir) {
  Fixture(dir);int checks=0;void Check(bool b,string name){if(!b)throw new Exception("FAIL "+name);checks++;Console.WriteLine("PASS "+name);}
  var w=Convert(dir,1408,1664,48,48,4096);
  Check(w.terrain.Length==2304,"sample count");Check(w.terrain.Single(t=>t.x==1408&&t.y==1664).z==0,"absolute origin");
  Check(w.terrain.Single(t=>t.x==1417&&t.y==1681).z==2,"column-major blocks and row-major cells");
  Check(w.terrain.Single(t=>t.x==1445&&t.y==1664).z==-5,"signed negative elevation");
  Check(w.statics.Length==72,"static count");Check(w.statics.Any(s=>s.x==1412&&s.y==1668&&s.z==-3&&s.id==101&&s.hue==17),"static coordinate z id hue");
  var crop=Convert(dir,1411,1667,9,11,4096);Check(crop.terrain.Length==99&&crop.statics.All(s=>s.x>=1411&&s.x<1420&&s.y>=1667&&s.y<1678),"unaligned crop");
  Check(Hash("")==0xdeadbeefdeadbeefUL,"lookup3 empty vector");
  byte[] raw=File.ReadAllBytes(Path.Combine(dir,"map1.mul"));
  foreach(bool compressed in new[]{false,true}){
   string file=Path.Combine(dir,"map1LegacyMUL.uop");using(var bw=new BinaryWriter(File.Create(file))){int chunkSize=4096*196,count=(raw.Length+chunkSize-1)/chunkSize;bw.Write(0x0050594du);bw.Write(5u);bw.Write(0u);bw.Write(28L);bw.Write(count);bw.Write(count);bw.Write(count);bw.Write(0L);long payload=40L+count*34;for(int n=0;n<count;n++){byte[] chunk=raw.Skip(n*chunkSize).Take(chunkSize).ToArray();byte[] bytes=chunk;if(compressed){using var ms=new MemoryStream();using(var z=new ZLibStream(ms,CompressionLevel.Fastest,true))z.Write(chunk);bytes=ms.ToArray();}long entry=bw.BaseStream.Position;bw.Write(payload);bw.Write(0);bw.Write(bytes.Length);bw.Write(chunk.Length);bw.Write(Hash($"build/map1legacymul/{n:D8}.dat"));bw.Write(0u);bw.Write((ushort)(compressed?1:0));bw.BaseStream.Position=payload;bw.Write(bytes);payload+=bytes.Length;bw.BaseStream.Position=entry+34;}}
   using var br=Read(file);var u=new Uop(br);Check(u.Chunk(22).SequenceEqual(raw.Skip(22*4096*196).Take(4096*196)),"UOP chunk "+compressed);
  }
  File.Move(Path.Combine(dir,"map1.mul"),Path.Combine(dir,"saved.mul"),true);var packedWorld=Convert(dir,1408,1664,48,48,4096);Check(packedWorld.terrain.SequenceEqual(w.terrain)&&packedWorld.statics.SequenceEqual(w.statics),"MUL/UOP IR equivalence");File.Move(Path.Combine(dir,"saved.mul"),Path.Combine(dir,"map1.mul"),true);
  File.WriteAllText(Path.Combine(dir,"mapdifl1.mul"),"");bool refused=false;try{Convert(dir,1408,1664,48,48,4096);}catch(NotSupportedException){refused=true;}File.Delete(Path.Combine(dir,"mapdifl1.mul"));Check(refused,"refuse ignored patches");
  using(var list=new BinaryWriter(File.Create(Path.Combine(dir,"mapdifl1.mul"))))list.Write(176*512+208);
  using(var patch=new BinaryWriter(File.Create(Path.Combine(dir,"mapdif1.mul")))){patch.Write(0u);for(int i=0;i<64;i++){patch.Write((ushort)999);patch.Write((sbyte)-11);}}
  using(var list=new BinaryWriter(File.Create(Path.Combine(dir,"stadifl1.mul")))){list.Write(176*512+208);list.Write(176*512+208);}
  using(var patch=new BinaryWriter(File.Create(Path.Combine(dir,"stadif1.mul")))){patch.Write((ushort)500);patch.Write((byte)1);patch.Write((byte)2);patch.Write((sbyte)-12);patch.Write((ushort)42);}
  using(var index=new BinaryWriter(File.Create(Path.Combine(dir,"stadifi1.mul")))){index.Write(-1);index.Write(0);index.Write(0);index.Write(0);index.Write(7);index.Write(0);}
  var overlay=Convert(dir,1408,1664,48,48,4096);Check(overlay.terrain.Single(t=>t.x==1408&&t.y==1664).z==-11&&overlay.terrain.First().id==999,"terrain diff precedence");Check(overlay.statics.Length==71&&overlay.statics.Any(s=>s.id==500&&s.x==1409&&s.y==1666&&s.z==-12&&s.hue==42),"static diff replacement, last duplicate wins");
  foreach(var name in new[]{"mapdifl1.mul","mapdif1.mul","stadifl1.mul","stadif1.mul","stadifi1.mul"})File.Delete(Path.Combine(dir,name));
  foreach(bool modern in new[]{false,true}) {
   string path=Path.Combine(dir,"tiledata.mul");int flagBytes=modern?8:4;long landSize=512L*(4+32*(flagBytes+22));
   using(var bw=new BinaryWriter(File.Create(path))){bw.BaseStream.SetLength(modern?3188736:2861056);bw.BaseStream.Position=4;if(modern)bw.Write(0x100000002UL);else bw.Write(2u);bw.Write((ushort)7);bw.Write(Encoding.ASCII.GetBytes("test grass"));}
   using(var bw=new BinaryWriter(File.OpenWrite(path))){bw.BaseStream.Position=landSize+(1L)*(4+32*(flagBytes+33))+4+(1)*(flagBytes+33);if(modern)bw.Write(0x100000004UL);else bw.Write(4u);bw.Write(new byte[12]);bw.Write((byte)20);bw.Write(Encoding.ASCII.GetBytes("test wall"));}
   using(var td=Read(path)){var a=ReadTileInfo(td,0,false);var b=ReadTileInfo(td,33,true);Check(a.name=="test grass"&&a.flags==(modern?0x100000002UL:2UL),"tiledata land layout/flags "+modern);Check(b.name=="test wall"&&b.height==20&&b.flags==(modern?0x100000004UL:4UL),"tiledata static group/height "+modern);}
   File.Delete(path);
  }
  using(var f=File.OpenWrite(Path.Combine(dir,"staidx1.mul")))f.SetLength(10);bool truncated=false;try{Convert(dir,1408,1664,48,48,4096);}catch(InvalidDataException){truncated=true;}Check(truncated,"truncation rejection");
  var gumpPixels=GumpArt.Decode(new byte[]{1,0,0,0,0,124,1,0,0,0,1,0},2,1);
  Check(gumpPixels[0]==255 && gumpPixels[3]==255 && gumpPixels[7]==0,"gump row lookup, RGB555 and transparent run");
  bool badGump=false;try{GumpArt.Decode(new byte[]{1,0,0,0,0,124,3,0},2,1);}catch(InvalidDataException){badGump=true;}
  Check(badGump,"gump row overflow rejected");
  Console.WriteLine($"ALL {checks} CHECKS PASSED");
 }
}
