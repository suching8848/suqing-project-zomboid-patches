from pathlib import Path
import subprocess, json
root=Path(__file__).parent
src=root/'tests'/'stubs'
files={
'zombie/iso/IsoCell.java':'''package zombie.iso; import java.util.*; import zombie.vehicles.BaseVehicle; public class IsoCell { public final Collection<BaseVehicle> vehicles=new ArrayList<>(); }''',
'zombie/iso/IsoChunk.java':'''package zombie.iso; import java.util.*; import zombie.vehicles.BaseVehicle; public class IsoChunk { public boolean loaded=true; public int wx=5,wy=7; public final List<Object> refs=new ArrayList<>(); public final List<BaseVehicle> vehicles=new ArrayList<>(); }''',
'zombie/iso/IsoGridSquare.java':'''package zombie.iso; public class IsoGridSquare { public IsoChunk chunk; }''',
'zombie/iso/IsoWorld.java':'''package zombie.iso; public class IsoWorld { public static IsoWorld instance; public IsoCell currentCell; }''',
'zombie/network/GameClient.java':'''package zombie.network; public class GameClient { public static boolean client=false; }''',
'zombie/network/GameServer.java':'''package zombie.network; public class GameServer { public static boolean server=false; }''',
'zombie/vehicles/VehicleParts.java':'''package zombie.vehicles; public class VehicleParts { public Object owner; public VehicleParts(Object x){owner=x;} public Object getOwner(){return owner;} }''',
'zombie/vehicleSound/VehicleSounds.java':'''package zombie.vehicleSound; public class VehicleSounds { public Object owner; public VehicleSounds(Object x){owner=x;} public Object getOwner(){return owner;} }''',
'zombie/vehicles/BaseVehicle.java':'''package zombie.vehicles; import zombie.iso.*; import zombie.vehicleSound.*; public class BaseVehicle { public IsoChunk chunk; public IsoCell cell; public IsoGridSquare square,current; public boolean addedToWorld=true, removed=false,failOriginal=false; public float x=41,y=57,z=0; public int originalCalls; public VehicleParts parts=new VehicleParts(this); public VehicleSounds sounds=new VehicleSounds(this); public boolean isRemovedFromWorld(){return removed;} public float getX(){return x;} public float getY(){return y;} public float getZ(){return z;} public IsoCell getCell(){return cell;} public IsoGridSquare getSquare(){return square;} public IsoGridSquare getCurrentSquare(){return current;} public VehicleParts getParts(){return parts;} public VehicleSounds getVehicleSounds(){return sounds;} public int getSqlId(){return 123;} public String getScriptName(){return "Base.TestVehicle";} public void update(){originalCalls++;if(failOriginal)throw new IllegalStateException("ordinary-original-error");if(removed)return;if(chunk==null)throw new NullPointerException("original-null-chunk");} }''',
'me/zed_0xff/zombie_buddy/Patch.java':'''package me.zed_0xff.zombie_buddy; import java.lang.annotation.*; @Retention(RetentionPolicy.RUNTIME) @Target(ElementType.TYPE) public @interface Patch { String className();String methodName();boolean strictMatch() default false; @Target(ElementType.METHOD) @interface OnEnter {} @Target(ElementType.PARAMETER) @interface This {} }''',
'suqingworldstateguard/Compatibility.java':'''package suqingworldstateguard; public class Compatibility { public static boolean supported=true;public static boolean isVehicleSupported(){return supported;} }''',
'suqingworldstateguard/VehicleGuardRegression.java':r'''package suqingworldstateguard;
import java.util.*; import java.util.function.Consumer; import zombie.iso.*; import zombie.vehicles.*; import zombie.network.*;
public class VehicleGuardRegression {
 static int checks;
 static BaseVehicle valid(){GameClient.client=false;GameServer.server=false;Compatibility.supported=true;IsoWorld.instance=new IsoWorld();BaseVehicle v=new BaseVehicle();v.cell=new IsoCell();IsoWorld.instance.currentCell=v.cell;IsoChunk c=new IsoChunk();c.refs.add(new Object());c.vehicles.add(v);v.square=new IsoGridSquare();v.square.chunk=c;v.current=v.square;v.cell.vehicles.add(v);return v;}
 static void check(boolean b,String m){checks++;if(!b)throw new AssertionError(m);}
 static void invoke(BaseVehicle v){PatchVehicleChunk.enter(v);v.update();}
 static void rejected(String name,Consumer<BaseVehicle> alter){BaseVehicle v=valid();alter.accept(v);IsoChunk c=v.square==null?null:v.square.chunk;Object[] cellBefore=v.cell==null?null:v.cell.vehicles.toArray();Object[] chunkBefore=c==null?null:c.vehicles.toArray();try{invoke(v);check(v.removed,name+" original must retain null error");}catch(NullPointerException expected){check(!v.removed,name+" original still errors");}check(v.originalCalls==1,name+" original called once");check(v.chunk==null,name+" no restore");if(cellBefore!=null)check(Arrays.equals(cellBefore,v.cell.vehicles.toArray()),name+" cell untouched");if(chunkBefore!=null)check(Arrays.equals(chunkBefore,c.vehicles.toArray()),name+" chunk untouched");}
 public static void main(String[] args){
  BaseVehicle v=valid();IsoChunk c=v.square.chunk;Object[] a=v.cell.vehicles.toArray(),b=c.vehicles.toArray();invoke(v);check(v.chunk==c,"unique owner restored");check(v.originalCalls==1,"full original update continues");check(Arrays.equals(a,v.cell.vehicles.toArray()),"cell contents unchanged");check(Arrays.equals(b,c.vehicles.toArray()),"chunk contents unchanged");
  BaseVehicle normal=valid();IsoChunk existing=new IsoChunk();normal.chunk=existing;normal.cell=null;invoke(normal);check(normal.chunk==existing,"existing chunk untouched even if other states irregular");check(normal.originalCalls==1,"normal original called");
  BaseVehicle noSounds=valid();noSounds.sounds=null;invoke(noSounds);check(noSounds.chunk==noSounds.square.chunk,"absent sounds have no foreign owner");
  rejected("missing-cell-membership",x->x.cell.vehicles.clear());
  rejected("duplicate-cell-membership",x->x.cell.vehicles.add(x));
  rejected("missing-chunk-membership",x->x.square.chunk.vehicles.clear());
  rejected("duplicate-chunk-membership",x->x.square.chunk.vehicles.add(x));
  rejected("foreign-parts-owner",x->x.parts.owner=new Object());
  rejected("missing-parts",x->x.parts=null);
  rejected("foreign-sounds-owner",x->x.sounds.owner=new Object());
  rejected("current-square-mismatch",x->x.current=new IsoGridSquare());
  rejected("missing-square",x->x.square=null);
  rejected("missing-chunk",x->x.square.chunk=null);
  rejected("unloaded-chunk",x->x.square.chunk.loaded=false);
  rejected("unreferenced-chunk",x->x.square.chunk.refs.clear());
  rejected("different-current-cell",x->IsoWorld.instance.currentCell=new IsoCell());
  rejected("missing-world",x->IsoWorld.instance=null);
  rejected("not-added",x->x.addedToWorld=false);
  rejected("removed",x->x.removed=true);
  rejected("nonfinite-position",x->x.x=Float.NaN);
  rejected("multiplayer-client",x->GameClient.client=true);
  rejected("multiplayer-server",x->GameServer.server=true);
  rejected("unsupported-class-gate",x->Compatibility.supported=false);
  BaseVehicle failing=valid();failing.chunk=failing.square.chunk;failing.failOriginal=true;try{invoke(failing);throw new AssertionError("ordinary error swallowed");}catch(IllegalStateException expected){check(expected.getMessage().equals("ordinary-original-error"),"ordinary original error propagated");check(failing.originalCalls==1,"ordinary failure original called");}
  System.out.println("PASS VehicleGuardRegression checks="+checks+"; real game classes never loaded");
 }
}'''
}
for p,c in files.items():
 out=src/p;out.parent.mkdir(parents=True,exist_ok=True);out.write_text(c,encoding='utf-8')
jdk=Path(r'E:\code\kp_1016\lab2_evidence\ide-extensions\redhat.java-1.58.0-win32-x64\jre\25.0.4.1-win32-x86_64\bin')
classes=root/'tests'/'classes';classes.mkdir(exist_ok=True)
args=[str(jdk/'javac.exe'),'-d',str(classes)]+[str(p) for p in src.rglob('*.java')]+[str(p) for p in (root/'source').rglob('*.java')]
build=subprocess.run(args,capture_output=True,text=True,encoding='utf-8',errors='replace');(root/'tests'/'compile.log').write_text(build.stdout+build.stderr,encoding='utf-8')
if build.returncode: print(build.stdout+build.stderr);raise SystemExit(build.returncode)
run=subprocess.run([str(jdk/'java.exe'),'-cp',str(classes),'suqingworldstateguard.VehicleGuardRegression'],capture_output=True,text=True,encoding='utf-8',errors='replace')
(root/'tests'/'regression.log').write_text(run.stdout+run.stderr,encoding='utf-8')
(root/'tests'/'result.json').write_text(json.dumps({'compile_exit':build.returncode,'run_exit':run.returncode,'environment':'JDK25 standalone stubs, no game process or game classes loaded','output':run.stdout,'stderr':run.stderr},indent=2),encoding='utf-8')
print(run.stdout+run.stderr);raise SystemExit(run.returncode)
