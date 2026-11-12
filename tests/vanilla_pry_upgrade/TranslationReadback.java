import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import zombie.ZomboidFileSystem;
import zombie.core.Core;
import zombie.core.Languages;
import zombie.core.Translator;

public final class TranslationReadback {
    public static void main(String[] args) throws Exception {
        var fs = ZomboidFileSystem.instance;
        fs.setCacheDir(args[0]);
        fs.init();
        fs.setModFoldersOrder("mods");
        var modId = "SuQingVanillaPryUpgrade";
        fs.loadMods(List.of(modId));
        if (!fs.getModIDs().contains(modId)) {
            throw new AssertionError("The test mod was not loaded");
        }

        Languages.instance.init();
        var rows = Files.readAllLines(Path.of(args[1]), StandardCharsets.UTF_8);
        boolean expectMissing = args.length > 2 && args[2].equals("missing");
        for (var language : List.of("CN", "EN")) {
            var definition = Languages.instance.getByName(language);
            if (definition == null) {
                throw new AssertionError("Missing language " + language);
            }
            Core.getInstance().setOptionLanguageName(language);
            Translator.loadFiles();

            int count = 0;
            for (var row : rows) {
                var columns = row.split("\t", 3);
                if (!columns[0].equals(language)) {
                    continue;
                }
                String key = columns[1];
                String expected = expectMissing && key.contains("_SuQingPry_") ? key : columns[2];
                String actual = Translator.getText(key);
                if (!expected.equals(actual)) {
                    throw new AssertionError(language + " " + key + " expected [" + expected + "] got [" + actual + "]");
                }
                count++;
            }
            if (count == 0) {
                throw new AssertionError("No expected translations for " + language);
            }
            System.out.println("PASS native Translator " + language + " " + count + " keys");
        }
    }
}
