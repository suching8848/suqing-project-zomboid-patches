package repro;
import zombie.characters.*;import zombie.characters.animals.IsoAnimal;import zombie.characterTextures.BloodBodyPartType;
import zombie.core.skinnedmodel.visual.HumanVisual;import java.lang.reflect.*;
public class WovenHoleRegression {
 static int checks;static void yes(boolean b,String m){checks++;if(!b)throw new AssertionError(m);}
 static Method guard;
 static boolean protectedCall(IsoGameCharacter c,BloodBodyPartType p,boolean all)throws Throwable{
  return c.addHole(p,all);
 }
 public static void main(String[]a)throws Throwable{

  IsoAnimal raw=new IsoAnimal();yes(!raw.addHole(BloodBodyPartType.Head,false),"woven skip returns original boolean default false");
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
}