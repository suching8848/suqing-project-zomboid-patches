from pathlib import Path
import subprocess, shutil, json

ROOT=Path(__file__).resolve().parent
JDK=Path(r'E:\code\kp_1016\lab2_evidence\ide-extensions\redhat.java-1.58.0-win32-x64\jre\25.0.4.1-win32-x86_64\bin')
ASM=Path(r'E:\code\kp_1016\lab2_evidence\ide-extensions\redhat.java-1.58.0-win32-x64\server\plugins\org.objectweb.asm_9.10.1.jar')
SRC={
'zombie/characters/IsoGameCharacter.java':r'''package zombie.characters;
import zombie.characterTextures.BloodBodyPartType; import zombie.core.skinnedmodel.visual.ItemVisuals;
public class IsoGameCharacter {
 public static ItemVisuals tempItemVisuals=new ItemVisuals();
 public static pzopt.Tl pzoptTempItemVisuals=new pzopt.Tl();
 public boolean updateModelTextures; public int getItemVisualCalls;public ItemVisuals worn=new ItemVisuals();
 public void getItemVisuals(ItemVisuals out){getItemVisualCalls++;out.clear();out.addAll(worn);}
 public boolean addHole(BloodBodyPartType part,boolean allLayers){throw new AssertionError("not injected");}
}''',
'zombie/characters/IsoPlayer.java':r'''package zombie.characters;
import zombie.core.skinnedmodel.visual.*;
public class IsoPlayer extends IsoGameCharacter implements IHumanVisual {
 public HumanVisual humanVisual; public boolean local;
 public HumanVisual getHumanVisual(){return humanVisual;}
 public boolean isLocalPlayer(){return local;}
}''',
'zombie/characters/animals/IsoAnimal.java':r'''package zombie.characters.animals;
public class IsoAnimal extends zombie.characters.IsoPlayer {}''',
'zombie/core/skinnedmodel/visual/IHumanVisual.java':r'''package zombie.core.skinnedmodel.visual;
public interface IHumanVisual {HumanVisual getHumanVisual();}''',
'zombie/core/skinnedmodel/visual/HumanVisual.java':r'''package zombie.core.skinnedmodel.visual;
public class HumanVisual {public int holes;public zombie.characterTextures.BloodBodyPartType lastPart;
 public void setHole(zombie.characterTextures.BloodBodyPartType part){holes++;lastPart=part;}}
''',
'zombie/core/skinnedmodel/visual/ItemVisuals.java':r'''package zombie.core.skinnedmodel.visual;
public class ItemVisuals extends java.util.ArrayList<ItemVisual> {}''',
'zombie/core/skinnedmodel/visual/ItemVisual.java':r'''package zombie.core.skinnedmodel.visual;
import zombie.characterTextures.BloodBodyPartType; import zombie.inventory.InventoryItem; import zombie.scripting.objects.Item;
public class ItemVisual {public Item script;public InventoryItem inventory;public int holes;
public Item getScriptItem(){return script;} public InventoryItem getInventoryItem(){return inventory;}
public float getHole(BloodBodyPartType p){return holes;} public void setHole(BloodBodyPartType p){holes++;}}
''',
'zombie/characterTextures/BloodBodyPartType.java':r'''package zombie.characterTextures;
public enum BloodBodyPartType {Head,Hand_L,MAX;public int index(){return ordinal();}public static BloodBodyPartType FromIndex(int n){return values()[n];}}
''',
'zombie/characterTextures/BloodClothingType.java':r'''package zombie.characterTextures;
import zombie.core.skinnedmodel.visual.*;import zombie.inventory.types.Clothing;
public class BloodClothingType {
 public java.util.List<BloodBodyPartType> coveredParts=new java.util.ArrayList<>();
 public static boolean addHole(BloodBodyPartType p,HumanVisual v,java.util.ArrayList<ItemVisual> i,boolean all){throw new AssertionError("not injected");}
 private static void setConditionAndSync(Clothing c,int n){c.setCondition(n);}
}
''',
'zombie/core/skinnedmodel/population/OutfitRNG.java':r'''package zombie.core.skinnedmodel.population;
public class OutfitRNG {public static int calls;public static int Next(int a,int b){calls++;return a;}}
''',
'zombie/core/random/Rand.java':r'''package zombie.core.random; public class Rand{public static boolean NextBool(int n){return false;}}''',
'zombie/network/GameServer.java':r'''package zombie.network;public class GameServer {public static boolean server;}''',
'zombie/Lua/LuaEventManager.java':r'''package zombie.Lua;
public class LuaEventManager {public static int events;public static Object lastCharacter;
public static void triggerEvent(String key,Object value){events++;lastCharacter=value;}}
''',
'zombie/inventory/InventoryItem.java':r'''package zombie.inventory;
public class InventoryItem {public int condition=100;public boolean isBroken(){return false;}public int getCondition(){return condition;}public void setCondition(int n){condition=n;}}
''',
'zombie/inventory/types/Clothing.java':r'''package zombie.inventory.types;
public class Clothing extends zombie.inventory.InventoryItem{
public void removePatch(zombie.characterTextures.BloodBodyPartType p){} public float getCondLossPerHole(){return 1;}public int getConditionLowerChance(){return 1;}}
''',
'zombie/scripting/objects/Item.java':r'''package zombie.scripting.objects;
public class Item{public Boolean canHaveHoles=true;public java.util.ArrayList<zombie.characterTextures.BloodClothingType> bloodTypes=new java.util.ArrayList<>();public java.util.ArrayList<zombie.characterTextures.BloodClothingType> getBloodClothingType(){return bloodTypes;}}
''',
'zombie/util/Type.java':r'''package zombie.util;public class Type{public static <T>T tryCastTo(Object x,Class<T> c){return c.isInstance(x)?c.cast(x):null;}}''',
'pzopt/Tl.java':r'''package pzopt;public class Tl {private final ThreadLocal<zombie.core.skinnedmodel.visual.ItemVisuals> slot=ThreadLocal.withInitial(zombie.core.skinnedmodel.visual.ItemVisuals::new);public Object get(){return slot.get();}}''',
'repro/GuardReference.java':r'''package repro;public class GuardReference{public static boolean applies(zombie.characters.IsoGameCharacter c){return c instanceof zombie.characters.animals.IsoAnimal && ((zombie.core.skinnedmodel.visual.IHumanVisual)c).getHumanVisual()==null;}}''',
'repro/ResourceGateRunner.java':r'''package repro;
import java.nio.file.*;import java.net.*;import java.io.*;import java.lang.reflect.*;
public class ResourceGateRunner {
 public static void main(String[]a)throws Throwable{
  byte[]animal=Files.readAllBytes(Path.of(a[2]));byte[]vehicle=Files.readAllBytes(Path.of(a[3]));
  try(URLClassLoader loader=new URLClassLoader(new URL[]{Path.of(a[0]).toUri().toURL(),Path.of(a[1]).toUri().toURL()},ClassLoader.getPlatformClassLoader()){
   public InputStream getResourceAsStream(String name){if(name.equals("zombie/characters/IsoGameCharacter.class"))return new ByteArrayInputStream(animal);if(name.equals("zombie/vehicles/BaseVehicle.class"))return new ByteArrayInputStream(vehicle);return super.getResourceAsStream(name);}
  }){
   String target=a[4].equals("known")?"repro.HoleRegression":"repro.GateReject";
   try{loader.loadClass(target).getMethod("main",String[].class).invoke(null,(Object)new String[]{"suqingworldstateguard.AnimalHoleGuard","shouldSkip",a[4]});}
   catch(InvocationTargetException e){throw e.getCause();}
  }
 }
}''',
'repro/GateReject.java':r'''package repro;
import java.lang.reflect.*;import zombie.characters.*;import zombie.characters.animals.IsoAnimal;import zombie.characterTextures.BloodBodyPartType;
public class GateReject {
 public static void main(String[]a)throws Throwable{
  Class<?>compat=Class.forName("suqingworldstateguard.Compatibility");
  if((boolean)compat.getMethod("isAnimalSupported").invoke(null))throw new AssertionError("unknown resource accepted");
  Method guard=Class.forName(a[0]).getMethod(a[1],IsoGameCharacter.class);IsoAnimal animal=new IsoAnimal();
  if((boolean)guard.invoke(null,animal))throw new AssertionError("unknown class guard activated");
  try{animal.addHole(BloodBodyPartType.Head,false);throw new AssertionError("native exception hidden");}catch(NullPointerException expected){}
  if((boolean)compat.getMethod("isAllowedAnimalHash",String.class).invoke(null,(Object)null))throw new AssertionError("null hash accepted");
  if((boolean)compat.getMethod("isAllowedAnimalHash",String.class).invoke(null,"0000000000000000000000000000000000000000000000000000000000000000"))throw new AssertionError("wrong hash accepted");
  System.out.println("PASS unknown resource gate: refused activation and retained native error");
 }
}''',
'repro/ExtractMethods.java':r'''package repro;
import java.nio.file.*;import org.objectweb.asm.*;
public class ExtractMethods {
 static void inject(Path source,Path target,String name,String desc)throws Exception{
  ClassWriter w=new ClassWriter(0);final int[]found={0,0};
  new ClassReader(Files.readAllBytes(target)).accept(new ClassVisitor(Opcodes.ASM9,w){
   public MethodVisitor visitMethod(int access,String n,String d,String sig,String[]ex){if(n.equals(name)&&d.equals(desc)){found[0]++;return null;}return super.visitMethod(access,n,d,sig,ex);}
   public void visitEnd(){}
  },0);
  new ClassReader(Files.readAllBytes(source)).accept(new ClassVisitor(Opcodes.ASM9){
   public MethodVisitor visitMethod(int access,String n,String d,String sig,String[]ex){if(n.equals(name)&&d.equals(desc)){found[1]++;return w.visitMethod(access,n,d,sig,ex);}return null;}
  },0);
  if(found[0]!=1||found[1]!=1)throw new AssertionError("missing/duplicate method");w.visitEnd();Files.write(target,w.toByteArray());
 }
 public static void main(String[]a)throws Exception{
  inject(Path.of(a[0]),Path.of(a[2],"zombie/characters/IsoGameCharacter.class"),"addHole","(Lzombie/characterTextures/BloodBodyPartType;Z)Z");
  inject(Path.of(a[1]),Path.of(a[2],"zombie/characterTextures/BloodClothingType.class"),"addHole","(Lzombie/characterTextures/BloodBodyPartType;Lzombie/core/skinnedmodel/visual/HumanVisual;Ljava/util/ArrayList;Z)Z");
 }
}''',
'repro/HoleRegression.java':r'''package repro;
import zombie.characters.*;import zombie.characters.animals.IsoAnimal;import zombie.characterTextures.BloodBodyPartType;
import zombie.core.skinnedmodel.visual.HumanVisual;import java.lang.reflect.*;
public class HoleRegression {
 static int checks;static void yes(boolean b,String m){checks++;if(!b)throw new AssertionError(m);}
 static Method guard;
 static boolean protectedCall(IsoGameCharacter c,BloodBodyPartType p,boolean all)throws Throwable{
  boolean skip;try{skip=(boolean)guard.invoke(null,c);}catch(InvocationTargetException e){throw e.getCause();}
  return skip?false:c.addHole(p,all);
 }
 public static void main(String[]a)throws Throwable{
  guard=Class.forName(a[0]).getDeclaredMethod(a[1],IsoGameCharacter.class);guard.setAccessible(true);
  IsoAnimal raw=new IsoAnimal();try{raw.addHole(BloodBodyPartType.Head,false);throw new AssertionError("expected animal null NPE");}catch(NullPointerException expected){yes(expected.getStackTrace()[0].getClassName().equals("zombie.characterTextures.BloodClothingType"),"actual target NPE site");}
  IsoAnimal animal=new IsoAnimal();yes(!protectedCall(animal,BloodBodyPartType.Head,false),"animal returns false");yes(animal.getItemVisualCalls==0,"animal null skip before visual access");yes(!animal.updateModelTextures,"animal skip leaves texture flag");int damageCallbacks=0;protectedCall(animal,BloodBodyPartType.Head,true);damageCallbacks++;yes(damageCallbacks==1,"caller damage continuation preserved");
  IsoPlayer human=new IsoPlayer();human.local=true;human.humanVisual=new HumanVisual();yes(!protectedCall(human,BloodBodyPartType.Hand_L,true),"human return from native empty clothing");yes(human.humanVisual.holes==1&&human.humanVisual.lastPart==BloodBodyPartType.Hand_L,"human original visual call/part retained");yes(human.getItemVisualCalls==1&&human.updateModelTextures,"human original side effects retained");yes(zombie.Lua.LuaEventManager.events==1&&zombie.Lua.LuaEventManager.lastCharacter==human,"original local player event");
  IsoAnimal visualAnimal=new IsoAnimal();visualAnimal.humanVisual=new HumanVisual();yes(!protectedCall(visualAnimal,BloodBodyPartType.Head,false),"visual animal native return");yes(visualAnimal.humanVisual.holes==1&&visualAnimal.getItemVisualCalls==1,"visual animal unmodified native path");
  IsoPlayer brokenHuman=new IsoPlayer();try{protectedCall(brokenHuman,BloodBodyPartType.Head,false);throw new AssertionError("human error swallowed");}catch(NullPointerException expected){yes(true,"nonanimal exception propagated");}
  IsoGameCharacter nonvisual=new IsoGameCharacter();yes(!protectedCall(nonvisual,BloodBodyPartType.Head,false)&&nonvisual.getItemVisualCalls==0,"original nonhuman interface guard");
  IsoAnimal randomAnimal=new IsoAnimal();int before=zombie.core.skinnedmodel.population.OutfitRNG.calls;protectedCall(randomAnimal,null,false);yes(zombie.core.skinnedmodel.population.OutfitRNG.calls==before,"null animal skipped before random bodypart");
  IsoPlayer randomHuman=new IsoPlayer();randomHuman.humanVisual=new HumanVisual();protectedCall(randomHuman,null,false);yes(zombie.core.skinnedmodel.population.OutfitRNG.calls==before+1&&randomHuman.humanVisual.holes==1,"human null part native RNG path retained");
  for(boolean all:new boolean[]{false,true}){
   IsoPlayer clothed=new IsoPlayer();clothed.humanVisual=new HumanVisual();
   zombie.core.skinnedmodel.visual.ItemVisual item=new zombie.core.skinnedmodel.visual.ItemVisual();
   item.inventory=new zombie.inventory.types.Clothing();item.script=new zombie.scripting.objects.Item();
   zombie.characterTextures.BloodClothingType type=new zombie.characterTextures.BloodClothingType();type.coveredParts.add(BloodBodyPartType.Head);item.script.bloodTypes.add(type);clothed.worn.add(item);
   yes(protectedCall(clothed,BloodBodyPartType.Head,all),"clothing native true return retained");
   yes(item.holes==1&&item.inventory.getCondition()==99,"actual clothing hole and condition retained");
   yes(clothed.humanVisual.holes==(all?1:0),"allLayers parameter native behavior retained");
  }
  System.out.println("PASS actual-method fixture "+a[2]+": "+checks+" checks; no game process or gameplay scene executed");
 }
}'''
}
def run(args):
    p=subprocess.run([str(x) for x in args],capture_output=True)
    def dec(b):
        try:return b.decode('utf-8')
        except UnicodeDecodeError:return b.decode('gb18030',errors='replace')
    if p.returncode:raise RuntimeError(dec(p.stdout)+dec(p.stderr))
    return dec(p.stdout)
def build():
    src=ROOT/'fixture-src';base=ROOT/'fixture-base';src.mkdir(exist_ok=True);base.mkdir(exist_ok=True)
    for name,body in SRC.items():
        path=src/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(body,encoding='utf-8')
    print(run([JDK/'javac.exe','-cp',ASM,'-d',base,*src.rglob('*.java')]))
    variants={'vanilla':ROOT/'vanilla-classes/zombie/characters/IsoGameCharacter.class','installed':Path(r'D:\steam\steamapps\common\ProjectZomboid\zombie\characters\IsoGameCharacter.class')}
    for name,origin in variants.items():
        dest=ROOT/('fixture-'+name);shutil.copytree(base,dest,dirs_exist_ok=True)
        print(run([JDK/'java.exe','-cp',str(base)+';'+str(ASM),'repro.ExtractMethods',origin,ROOT/'vanilla-classes/zombie/characterTextures/BloodClothingType.class',dest]))
    print('Built independent actual-bytecode fixtures for vanilla and installed PZO')
if __name__=='__main__':build()
