// SPDX-License-Identifier: GPL-3.0-or-later
using System.IO.Compression;
using System.Text.Json;
using System.Text.RegularExpressions;

// Local art-direction catalogue of every item graphic, ranked by how often it
// is placed in the world. Outputs are proprietary derivatives (art PNGs and
// tiledata names) and belong only in the ignored outputs/ folder.
static class ItemCatalog {
 // Facet number, name, height in tiles; Felucca mirrors Trammel and is reported apart.
 static readonly (int facet,string name,int height)[] Facets={(1,"Trammel",4096),(0,"Felucca",4096),(2,"Ilshenar",1600),(3,"Malas",2048),(4,"Tokuno",1448),(5,"TerMur",4096)};
 static readonly string[] FlagNames={"background","weapon","transparent","translucent","wall","damaging","impassable","wet","unknown","surface","bridge","stackable","window","noshoot","article-a","article-an","article-the","foliage","partial-hue","no-house","map","container","wearable","light","animated","hover","no-diagonal","armor","roof","door","stair-back","stair-right"};
 static readonly Dictionary<int,string> Layers=new(){{1,"one hand"},{2,"two hands / shield"},{3,"shoes"},{4,"pants"},{5,"shirt"},{6,"helm"},{7,"gloves"},{8,"ring"},{9,"talisman"},{10,"neck"},{11,"hair"},{12,"waist"},{13,"inner torso"},{14,"bracelet"},{16,"beard"},{17,"middle torso"},{18,"earrings"},{19,"arms"},{20,"cloak"},{21,"backpack"},{22,"outer torso"},{23,"outer legs"},{24,"inner legs"},{25,"mount"}};
 record Entry(int id,string name,ulong flags,int height,int weight,int layer,int anim,int width,int artHeight,string? color=null);
 sealed class Usage {public long world,felucca,britain,decoration;public Dictionary<string,long> facets=new();public string? example;}

 public static void Export(string dir,string output,string decoration,int[] britain,string reviewed,string? colors=null) {
  output=Path.GetFullPath(output);string art=Path.Combine(output,"art");Directory.CreateDirectory(art);
  var usage=new Dictionary<int,Usage>();Usage Use(int id)=>usage.TryGetValue(id,out var u)?u:usage[id]=new Usage();
  foreach(var (facet,name,height) in Facets) {
   long placed=0;
   foreach(var (id,x,y,z) in Statics(dir,facet,height)) {
    var u=Use(id);placed++;u.facets[name]=u.facets.GetValueOrDefault(name)+1;
    if(facet==0)u.felucca++;else u.world++;
    if(facet==1&&x>=britain[0]&&y>=britain[1]&&x<britain[0]+britain[2]&&y<britain[1]+britain[3])u.britain++;
    if(u.example==null||(facet==1&&!u.example.StartsWith("Trammel")))u.example=$"{name} {x},{y},{z}";
   }
   Console.WriteLine($"{name}: {placed:N0} placed statics");
  }
  long decorated=0;
  if(Directory.Exists(decoration)) foreach(var file in Directory.EnumerateFiles(decoration,"*.cfg",SearchOption.AllDirectories)) {
   string folder=Path.GetFileName(Path.GetDirectoryName(file)!);bool fel=folder is "Felucca" or "RuinedMaginciaFel";int current=-1;
   foreach(var raw in File.ReadLines(file)) {
    var line=raw.Trim();if(line.Length==0||line.StartsWith('#'))continue;
    var header=Regex.Match(line,@"^([A-Za-z]\w*)\s+0x([0-9A-Fa-f]+)");
    if(header.Success){current=header.Groups[1].Value is "Spawner" or "Teleporter"?-1:System.Convert.ToInt32(header.Groups[2].Value,16);continue;}
    if(char.IsLetter(line[0])){current=-1;continue;}
    if(current<0)continue;var u=Use(current);u.decoration++;decorated++;
    if(fel)u.felucca++;else u.world++;u.facets["Server decoration"]=u.facets.GetValueOrDefault("Server decoration")+1;
   }
  }
  Console.WriteLine($"Server decoration: {decorated:N0} placed items");
  var models=new Dictionary<int,string>();
  if(File.Exists(reviewed)){using var doc=JsonDocument.Parse(File.ReadAllText(reviewed));foreach(var p in doc.RootElement.GetProperty("entries").EnumerateObject())models[int.Parse(p.Name)]=p.Value.TryGetProperty("asset",out var a)&&a.ValueKind==JsonValueKind.String?a.GetString()!:p.Value.GetProperty("kind").GetString()!;}
  using var tiles=new BinaryReader(File.OpenRead(Path.Combine(dir,"tiledata.mul")));using var arts=new ArtArchive(Path.Combine(dir,"artLegacyMUL.uop"));
  int count=StaticCount(tiles.BaseStream.Length);var entries=new List<Entry>();
  for(int id=0;id<count;id++) {
   var image=arts.Decode(id+0x4000);var info=Read(tiles,id);
   if(image==null&&!usage.ContainsKey(id))continue;
   if(image!=null)Png.Write(Path.Combine(art,$"{id}.png"),image.Value.width,image.Value.height,image.Value.rgba);
   entries.Add(info with{width=image?.width??0,artHeight=image?.height??0,color=image==null?null:Average(image.Value.rgba)});
  }
  // Families: same name and category, members within a few IDs of the previous one.
  var family=new Dictionary<int,string>();var families=new Dictionary<string,List<int>>();var open=new Dictionary<string,(string key,int last)>();
  foreach(var e in entries) {
   string label=Label(e.name),group=label+"|"+Category(e);
   if(!open.TryGetValue(group,out var run)||e.id-run.last>8){int n=1;string key=Slug(label);while(families.ContainsKey(key))key=$"{Slug(label)}_{++n}";run=(key,e.id);families[key]=new();}
   open[group]=(run.key,e.id);families[run.key].Add(e.id);family[e.id]=run.key;
  }
  var items=entries.Select(e=>{var u=usage.GetValueOrDefault(e.id)??new Usage();return new{
   e.id,hex=$"0x{e.id:X4}",name=Label(e.name),category=Category(e),family=family[e.id],flags=Flags(e.flags),e.height,e.weight,
   layer=(e.flags&0x400000)!=0?Layers.GetValueOrDefault(e.layer,$"layer {e.layer}"):null,anim=(e.flags&0x400000)!=0?e.anim:0,
   art=e.width>0?new[]{e.width,e.artHeight}:null,e.color,u.world,u.felucca,u.britain,u.decoration,u.facets,u.example,model=models.GetValueOrDefault(e.id)};}).ToList();
  var byId=items.ToDictionary(i=>i.id);
  var familyList=families.Select(f=>{var members=f.Value.Select(id=>byId[id]).ToList();return new{
   key=f.Key,name=members[0].name,category=members[0].category,ids=f.Value,world=members.Sum(i=>i.world),britain=members.Sum(i=>i.britain),
   modelled=members.Count(i=>i.model!=null)};}).OrderByDescending(f=>f.world).ThenBy(f=>f.ids[0]).ToList();
  var catalog=new{schema=1,notice="LOCAL REFERENCE ONLY: original Ultima Online artwork and names. Never commit or redistribute.",
   generated=DateTime.UtcNow.ToString("u"),britain,items=items.OrderByDescending(i=>i.world).ThenBy(i=>i.id),families=familyList};
  File.WriteAllText(Path.Combine(output,"catalog.js"),"window.CATALOG="+JsonSerializer.Serialize(catalog)+";");
  // Average art colours for graphics never placed in Britain: the client tints
  // regional floors, roofs and masonry with them. Local only (derived from art).
  if(colors!=null) File.WriteAllText(colors,JsonSerializer.Serialize(entries.Where(e=>e.color!=null&&usage.GetValueOrDefault(e.id)?.britain is null or 0).ToDictionary(e=>e.id.ToString(),e=>e.color)));
  Console.WriteLine($"LOCAL REFERENCE ONLY: {items.Count:N0} items ({items.Count(i=>i.art!=null):N0} with art, {items.Count(i=>i.world>0):N0} placed) in {familyList.Count:N0} families -> {output}");
 }

 // Mean colour of opaque pixels, ignoring near-black outline pixels.
 static string? Average(byte[] rgba) {
  long r=0,g=0,b=0,n=0;
  for(int p=0;p<rgba.Length;p+=4){if(rgba[p+3]==0||rgba[p]+rgba[p+1]+rgba[p+2]<40)continue;r+=rgba[p];g+=rgba[p+1];b+=rgba[p+2];n++;}
  return n==0?null:$"{r/n:x2}{g/n:x2}{b/n:x2}";
 }
 static string Label(string name)=>string.IsNullOrWhiteSpace(name)?"unnamed":Regex.Replace(name.Trim().ToLowerInvariant(),@"\s+"," ");
 static string Slug(string label)=>Regex.Replace(label,@"[^a-z0-9]+","_").Trim('_') is var s&&s.Length>0?s:"unnamed";
 static List<string> Flags(ulong flags)=>Enumerable.Range(0,FlagNames.Length).Where(b=>(flags&(1UL<<b))!=0).Select(b=>FlagNames[b]).ToList();
 static string Category(Entry e) {
  ulong f=e.flags;string n=e.name.ToLowerInvariant();
  // The tiledata "weapon" bit is set on nearly all wearables, so the worn layer decides.
  if((f&0x400000)!=0)return e.layer is 1 or 2?"weapons & shields":e.layer is 11 or 16?"hair & beards":
   (f&0x8000000)!=0||Regex.IsMatch(n,@"plate|chain|ring ?mail|leather|studded|bone|helm|gorget|bascinet|armou?r|sleeves|leggings|tunic of|kabuto|jingasa|do |hiro|suneate|haidate|mempo")&&!n.Contains("ring ")?"armour":"clothing & jewellery";
  if(n.StartsWith("nodraw")||n=="no draw"||n.Contains("invisible"))return "invisible (editor)";
  if(Regex.IsMatch(n,@"^(water|lava|acid|slime)\b|waterfall"))return "water & lava";
  if((f&0x20000000)!=0||n.Contains("door")||n.Contains("gate"))return "doors & gates";
  if((f&0x10000000)!=0||n.Contains("roof")||n.Contains("shingle")||n.Contains("thatch"))return "roofs";
  if((f&0xC0000000)!=0||n.Contains("stair")||n.Contains("step")||n.Contains("ladder"))return "stairs";
  if((f&0x1010)!=0||n.Contains("wall")||n.Contains("window")||n.Contains("arch")||n.Contains("pillar")||n.Contains("column"))return "walls & windows";
  if(Regex.IsMatch(n,@"^(marble|white marble|bricks|wood|sandstone|platform)$"))return "building materials";
  if(Regex.IsMatch(n,@"floor|tile|plank|boards|cobble|pavers|carpet|rug|flagstone"))return "floors & paving";
  if((f&0x20000)!=0||Regex.IsMatch(n,@"tree|bush|plant|grass|fern|flower|leaves|needles|vine|reed|cactus|mushroom|shrub|weed|branch|stump|log|lily|hay|crops?|corn|wheat|bramble|sapling|palm|bamboo|moss|cattail|thorn|ivy|hedge|rushes|morning glor|lill?y|algae|seaweed|coral|kelp"))return "nature";
  if(Regex.IsMatch(n,@"rock|stone|boulder|cave|dirt|sand|swamp|snow|ice|mud|crystal|stalag|gravel|pebble"))return "rocks & ground";
  if((f&0x800000)!=0||Regex.IsMatch(n,@"lamp|candle|torch|lantern|brazier|fire|sconce"))return "lights";
  if((f&0x200000)!=0)return "containers";
  if(Regex.IsMatch(n,@"table|chair|bench|stool|bed|shel|display case|cabinet|chest|armoire|dresser|counter|throne|desk|bookcase|drawer|wardrobe|loom|spinning|forge|anvil|oven|stove|fireplace"))return "furniture";
  if(Regex.IsMatch(n,@"web|garbage|trash|fence|post|sign|banner|statue|fountain|well|bridge|dock|pier|tent|ruin|rubble|bones|skull|blood|debris|grave|tomb|cross|shrine|altar|pentagram"))return "structures & decoration";
  if((f&0x2)!=0&&Regex.IsMatch(n,@"sword|axe|mace|bow|spear|dagger|staff|club|halberd|bardiche|kryss|katana|cutlass|scimitar|hammer|shield"))return "weapons & shields";
  if((f&0x800)!=0||Regex.IsMatch(n,@"food|bread|fruit|apple|meat|fish|cheese|pie|cake|bottle|mug|goblet|plate|bowl|pitcher|jug|cup|ingot|ore|hide|cloth|bolt|thread|reagent|scroll|book|potion|gem|coin|gold|tool|hammer|saw|tongs|pick|shovel|scissors|map|key"))return "small items";
  if((f&0x40)!=0)return "large objects";
  return "other";
 }
 static int StaticCount(long length)=>(int)((length-512L*(4+32*30))/(4+32*41))*32;
 static Entry Read(BinaryReader r,int id) {
  long offset=512L*(4+32*30)+(long)(id/32)*(4+32*41)+4+(id%32)*41;r.BaseStream.Position=offset;
  ulong flags=r.ReadUInt64();int weight=r.ReadByte(),layer=r.ReadByte();r.ReadInt32();int anim=r.ReadUInt16();r.ReadUInt16();r.ReadUInt16();int height=r.ReadByte();
  string name=System.Text.Encoding.ASCII.GetString(r.ReadBytes(20)).Split('\0')[0];
  return new(id,name,flags,height,weight,layer,anim,0,0);
 }
 // Every placed static of one facet, with local diff blocks taking precedence.
 static IEnumerable<(int id,int x,int y,int z)> Statics(string dir,int facet,int height) {
  string index=Path.Combine(dir,$"staidx{facet}.mul"),data=Path.Combine(dir,$"statics{facet}.mul");if(!File.Exists(index))yield break;
  var patched=new Dictionary<int,int>();string list=Path.Combine(dir,$"stadifl{facet}.mul");
  if(File.Exists(list)){var bytes=File.ReadAllBytes(list);for(int i=0;i+4<=bytes.Length;i+=4)patched[BitConverter.ToInt32(bytes,i)]=i/4;}
  using var idx=new BinaryReader(File.OpenRead(index));using var sta=new BinaryReader(File.OpenRead(data));
  using var pidx=patched.Count>0?new BinaryReader(File.OpenRead(Path.Combine(dir,$"stadifi{facet}.mul"))):null;using var psta=patched.Count>0?new BinaryReader(File.OpenRead(Path.Combine(dir,$"stadif{facet}.mul"))):null;
  int blocksY=height/8,blocks=(int)(idx.BaseStream.Length/12);var buffer=new byte[0];
  for(int block=0;block<blocks;block++) {
   bool diff=patched.TryGetValue(block,out int slot);var ir=diff?pidx!:idx;var sr=diff?psta!:sta;
   ir.BaseStream.Position=(long)(diff?slot:block)*12;int off=ir.ReadInt32(),len=ir.ReadInt32();ir.ReadInt32();
   if(off<0||len<=0||len%7!=0||off+(long)len>sr.BaseStream.Length)continue;
   sr.BaseStream.Position=off;buffer=sr.ReadBytes(len);int bx=block/blocksY,by=block%blocksY;
   for(int n=0;n<len;n+=7)yield return (BitConverter.ToUInt16(buffer,n),bx*8+buffer[n+2],by*8+buffer[n+3],(sbyte)buffer[n+4]);
  }
 }

 sealed class ArtArchive : IDisposable {
  readonly BinaryReader reader;readonly Dictionary<ulong,(long off,int packed,int raw,ushort flag)> entries=new();
  public ArtArchive(string path) {
   reader=new BinaryReader(File.OpenRead(path));if(reader.ReadUInt32()!=0x0050594d)throw new InvalidDataException("Art UOP signature");
   reader.ReadUInt32();reader.ReadUInt32();long next=reader.ReadInt64();var seen=new HashSet<long>();
   while(next!=0){if(!seen.Add(next)||next<0||next>reader.BaseStream.Length-12)throw new InvalidDataException("Art directory");reader.BaseStream.Position=next;int count=reader.ReadInt32();next=reader.ReadInt64();for(int i=0;i<count;i++){long off=reader.ReadInt64();int header=reader.ReadInt32(),packed=reader.ReadInt32(),raw=reader.ReadInt32();ulong hash=reader.ReadUInt64();reader.ReadUInt32();ushort flag=reader.ReadUInt16();if(off!=0&&packed>0)entries[hash]=(off+header,packed,raw,flag);}}
  }
  public (int width,int height,byte[] rgba)? Decode(int index) {
   if(!entries.TryGetValue(Program.Hash($"build/artlegacymul/{index:D8}.tga"),out var e)||e.raw<8||e.flag>1)return null;
   reader.BaseStream.Position=e.off;byte[] raw=reader.ReadBytes(e.packed);
   if(e.flag==1){using var z=new ZLibStream(new MemoryStream(raw),CompressionMode.Decompress);raw=new byte[e.raw];z.ReadExactly(raw);}
   try {
    using var art=new BinaryReader(new MemoryStream(raw));art.ReadUInt32();int width=art.ReadUInt16(),height=art.ReadUInt16();
    if(width<1||width>1024||height<1||height>1024)return null;
    var offsets=Enumerable.Range(0,height).Select(_=>art.ReadUInt16()).ToArray();long origin=art.BaseStream.Position;var rgba=new byte[width*height*4];
    for(int y=0;y<height;y++){art.BaseStream.Position=origin+offsets[y]*2;int x=0;while(true){int skip=art.ReadUInt16(),run=art.ReadUInt16();if(skip==0&&run==0)break;x+=skip;if(x+run>width)return null;for(int n=0;n<run;n++){int c=art.ReadUInt16(),p=(y*width+x++)*4;rgba[p]=(byte)(((c>>10)&31)*255/31);rgba[p+1]=(byte)(((c>>5)&31)*255/31);rgba[p+2]=(byte)((c&31)*255/31);rgba[p+3]=255;}}}
    return (width,height,rgba);
   } catch(EndOfStreamException){return null;}
  }
  public void Dispose()=>reader.Dispose();
 }
}

// Minimal RGBA PNG writer (zlib IDAT, CRC-32) so the converter needs no image library.
static class Png {
 static readonly uint[] Table=Enumerable.Range(0,256).Select(n=>{uint c=(uint)n;for(int k=0;k<8;k++)c=(c&1)!=0?0xEDB88320u^(c>>1):c>>1;return c;}).ToArray();
 public static void Write(string path,int width,int height,byte[] rgba) {
  using var file=File.Create(path);file.Write(new byte[]{137,80,78,71,13,10,26,10});
  var header=new byte[13];Big(header,0,(uint)width);Big(header,4,(uint)height);header[8]=8;header[9]=6;Chunk(file,"IHDR",header);
  using var packed=new MemoryStream();
  using(var z=new ZLibStream(packed,CompressionLevel.Optimal,true))for(int y=0;y<height;y++){z.WriteByte(0);z.Write(rgba,y*width*4,width*4);}
  Chunk(file,"IDAT",packed.ToArray());Chunk(file,"IEND",Array.Empty<byte>());
 }
 public static uint Crc(IEnumerable<byte> bytes){uint c=0xFFFFFFFFu;foreach(var b in bytes)c=Table[(c^b)&0xFF]^(c>>8);return c^0xFFFFFFFFu;}
 static void Big(byte[] b,int at,uint v){b[at]=(byte)(v>>24);b[at+1]=(byte)(v>>16);b[at+2]=(byte)(v>>8);b[at+3]=(byte)v;}
 static void Chunk(Stream s,string type,byte[] data) {
  var head=new byte[8];Big(head,0,(uint)data.Length);System.Text.Encoding.ASCII.GetBytes(type,0,4,head,4);s.Write(head);s.Write(data);
  var crc=new byte[4];Big(crc,0,Crc(head.Skip(4).Concat(data)));s.Write(crc);
 }
}
