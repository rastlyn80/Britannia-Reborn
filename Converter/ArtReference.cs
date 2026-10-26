using System.IO.Compression;
using System.Text.Json;

// Local inspection only: never package the resulting proprietary reference images.
static class ArtReference {
 public static void Export(string dir,string worldPath,string output, int[]? requested=null) {
  using var world=requested==null?JsonDocument.Parse(File.ReadAllText(worldPath)):null;
  var ids=requested??world!.RootElement.GetProperty("statics").EnumerateArray().Select(s=>s.GetProperty("id").GetInt32()).Distinct().Order().ToArray();
  using var reader=new BinaryReader(File.OpenRead(Path.Combine(dir,"artLegacyMUL.uop")));
  if(reader.ReadUInt32()!=0x0050594d)throw new InvalidDataException("Art UOP signature");
  reader.ReadUInt32();reader.ReadUInt32();long next=reader.ReadInt64();
  var entries=new Dictionary<ulong,(long off,int packed,int raw,ushort flag)>();var seen=new HashSet<long>();
  while(next!=0){if(!seen.Add(next)||next<0||next>reader.BaseStream.Length-12)throw new InvalidDataException("Art directory");reader.BaseStream.Position=next;int count=reader.ReadInt32();next=reader.ReadInt64();if(count<0||count>100000)throw new InvalidDataException("Art count");for(int i=0;i<count;i++){long off=reader.ReadInt64();int header=reader.ReadInt32(),packed=reader.ReadInt32(),raw=reader.ReadInt32();ulong hash=reader.ReadUInt64();reader.ReadUInt32();ushort flag=reader.ReadUInt16();if(off!=0)entries[hash]=(off+header,packed,raw,flag);}}
  var result=new List<object>();
  foreach(int id in ids){if(!entries.TryGetValue(Program.Hash($"build/artlegacymul/{id+0x4000:D8}.tga"),out var e)){Console.WriteLine($"Local artwork missing ID {id}");continue;}if(e.off<0||e.packed<0||e.raw<8||e.raw>16777216||e.off>reader.BaseStream.Length-e.packed||e.flag>1)throw new InvalidDataException("Art range");reader.BaseStream.Position=e.off;byte[] raw=reader.ReadBytes(e.packed);if(e.flag==1){using var input=new MemoryStream(raw);using var z=new ZLibStream(input,CompressionMode.Decompress);raw=new byte[e.raw];z.ReadExactly(raw);}
   using var art=new BinaryReader(new MemoryStream(raw));art.ReadUInt32();int width=art.ReadUInt16(),height=art.ReadUInt16();if(width<1||width>1024||height<1||height>1024)throw new InvalidDataException("Art dimensions");var offsets=Enumerable.Range(0,height).Select(_=>art.ReadUInt16()).ToArray();long origin=art.BaseStream.Position;byte[] rgba=new byte[width*height*4];
   for(int y=0;y<height;y++){art.BaseStream.Position=origin+offsets[y]*2;int x=0;while(true){int skip=art.ReadUInt16(),run=art.ReadUInt16();if(skip==0&&run==0)break;x+=skip;if(x+run>width)throw new InvalidDataException("Art run");for(int n=0;n<run;n++){int c=art.ReadUInt16(),p=(y*width+x++)*4;rgba[p]=(byte)(((c>>10)&31)*255/31);rgba[p+1]=(byte)(((c>>5)&31)*255/31);rgba[p+2]=(byte)((c&31)*255/31);rgba[p+3]=255;}}}
   result.Add(new{id,width,height,rgba=System.Convert.ToBase64String(rgba)});
  }
  File.WriteAllText(output,JsonSerializer.Serialize(result));Console.WriteLine($"LOCAL REFERENCE ONLY: {result.Count} art tiles decoded");
 }
}
