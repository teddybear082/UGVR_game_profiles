GDPC                 `                                                                         P   res://.godot/exported/133200997/export-bcb0d2eb5949c52b6a65bfe9de3e985b-Main.scn��      �      #� ����}3��I]    ,   res://.godot/global_script_class_cache.cfg  ��      r      ul�7;���Ok�����    L   res://.godot/imported/donate_icon.png-e44f274a86c8f4daccf0c652cf3d80a1.ctex p,      p      A�{E7����}����    D   res://.godot/imported/icon.png-487276ed1e3a0c39cad0279d744ee560.ctex�.      \	      ���M���W��F�V�}    D   res://.godot/imported/icon.svg-218a8f2b3041327d8a5756f3a245f83b.ctex�8      %      h�io �!��CA�o    P   res://.godot/imported/mws_logo_white.svg-9e2febccbc8e44d82ff854ce9d86db63.ctex  @�      �      HA���p-Ŵ�_�v�=    D   res://.godot/imported/pin.svg-8ffcbdbbbe25fd7c71979555d8a64c28.ctex и      �       Tҷ4B�s15�u���    L   res://.godot/imported/pin_disabled.svg-e939da60381f48a090424b6e442ff96f.ctex@�      �       4�q��?_+^���s       res://.godot/uid_cache.bin  ��      �       �;�LLD�f���x2       res://AutoUpdater.gd       O      �����r���h��I)�'       res://Main.gd   �^      �(      5���
����u��@       res://Main.tscn.remap   P�      a       3 J�M�B�b��}�       res://ModList.gd�      "      ��S��W�♂稪     (   res://ModLoader/MainLoopEntryPoint.gd           �       Dғ�u|.����E�5       res://ModLoader/ModLoader.gd�       k      ����(�q�ۮ���5    (   res://ModLoader/SubResourceEntryPoint.gd`      �      �t3�����xr u���       res://Settings.gd   �      %      e�n+�e�ϵY��j�o       res://VM_VERSION@�             ��5|�Lzc���)s       res://donate_icon.png.import�-      �       ���N?.�e��e�       res://icon.png  @�      i      R˭��jVĝe�u       res://icon.png.import   8      �       <E�	uc�R���Xu�       res://icon.svg.import   �]      �       ��y��Sthlو�J�        res://mws_logo_white.svg.import  �      �       `kI����g�ږ�b��J       res://pin.svg.import��      �       ��v�����x7�(�i        res://pin_disabled.svg.import   @�      �       ��y#��غ���韩�       res://project.binary��      �      ��p�<*��k���YT    extends SceneTree

func _initialize():
	var loader = load("ModLoader.gd").new()
	root.add_child(loader)
	loader.name = "ModLoader"
	
	change_scene_to_packed(load(ProjectSettings.get_setting_with_override("application/run/main_scene")))     extends Node

var loadedMods: Array[ModInfo] = []

signal modLoaded(mod: ModInfo)
signal allModsLoaded()

class ModInfo:
	var path: String
	var cfg: ConfigFile

func getModsDir() -> String:
	# Get the --main-pack option
	var modsDir = null
	var args = OS.get_cmdline_user_args()
	for i in range(args.size()):
		var arg = args[i]
		# Engine specific options stop
		if arg == "--" || arg == "++":
			break

		if !arg.begins_with("--"):
			continue
		
		var idx = arg.find('=')
		if idx == -1:
			if i == args.size():
				continue
			else:
				if arg == "--mods-dir":
					var val = args[i + 1]
					if val.begins_with("-") || val.begins_with("+"):
						continue
					modsDir = val
					break
		else:
			var key = arg.substr(2, idx)
			var val = arg.substr(idx + 1)
			if key == "mods-dir":
				modsDir = val
				break

	if modsDir:
		return modsDir

	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://") + "/mods"
	return OS.get_executable_path().get_base_dir() + "/mods"

func _ready():
	var modsDir = getModsDir()
	if !DirAccess.dir_exists_absolute(modsDir):
		DirAccess.make_dir_recursive_absolute(modsDir)

	print("Loading mods from ", modsDir)
	var da = DirAccess.open(modsDir)
	for mod in da.get_files():
		var zipPath = modsDir + "/" + mod

		if mod.ends_with(".zip.disabled"):
			continue
		elif mod.ends_with(".zip"):
			print("Loading ", zipPath)
		else:
			continue

		var zipReader = ZIPReader.new()
		var err = zipReader.open(zipPath)
		if err != OK:
			printerr("Failed to open mod ZIP: ", zipPath, "(", err, ")")
			continue
		
		if !zipReader.file_exists("mod.txt"):
			printerr("Cannot find mod.txt in ", zipPath)
			continue
		
		var cfgStr = zipReader.read_file("mod.txt").get_string_from_utf8()
		zipReader.close()

		var cfg = ConfigFile.new()
		var cfgErr = cfg.parse(cfgStr)
		if cfgErr != OK:
			printerr("Failed to parse mod.txt in ", zipPath, " (", cfgErr, ")")
			continue
		
		if !cfg.has_section_key("mod", "name"):
			printerr("No key 'name' in section [mod] in mod.txt in ", zipPath)
			continue
		var modname = cfg.get_value("mod", "name")
		
		if !cfg.has_section_key("mod", "id"):
			printerr("No key 'id' in section [mod] in mod.txt in ", zipPath)
			continue
		var id = cfg.get_value("mod", "id")
		
		if !cfg.has_section_key("mod", "version"):
			printerr("No key 'version' in section [mod] in mod.txt in ", zipPath)
			continue
		var version = cfg.get_value("mod", "version")
			
		var info = ModInfo.new()
		info.cfg = cfg
		info.path = zipPath

		print("Loading mod \"", modname, "\" (", id, " ", version, ")")
		ProjectSettings.load_resource_pack(zipPath)

		if cfg.has_section("autoload"):
			var entries = cfg.get_section_keys("autoload")
			for k in entries:
				var path = cfg.get_value("autoload", k)
				if !ResourceLoader.exists(path):
					printerr("Autoload '", path, "' defined by mod '", modname, "' does not exist")

				var autoloadRes = load(path)
				var node = null
				if autoloadRes is GDScript:
					node = autoloadRes.new()
				elif autoloadRes is PackedScene:
					node = autoloadRes.instantiate()
					
				if node is Node:
					node.name = k
					get_tree().root.add_child(node)
					print("Created autoload ", k, " defined by mod '", modname, "'")
				else:
					printerr("Autoload '", path, "' defined by mod '", modname, "' does not extend class Node!")

		print("Done")
		allModsLoaded.emit()

		loadedMods.append(info)
		modLoaded.emit(info)     extends Preferences

@export var loaderScript : GDScript

func _init():
	# Constructor is called BEFORE export variables are set
	load_loader.call_deferred()
	
func load_loader():
	if ProjectSettings.get_setting("vostokmods/is_injector", false):
		return
	if Engine.get_main_loop().root.has_node("ModLoader"):
		return

	var loader = loaderScript.new()
	Engine.get_main_loop().root.add_child.call_deferred(loader)
	loader.name = "ModLoader"        extends Node
class_name AutoUpdater

@export var Main : InjectorMain

func _ready() -> void:
	pass

func checkInjectorUpdate():
	var deletemePath = ProjectSettings.globalize_path(".").path_join("Injector.pck.deleteme")
	if FileAccess.file_exists(deletemePath):
		DirAccess.remove_absolute(deletemePath)

	var httpReq = HTTPRequest.new()
	add_child(httpReq)
	var err = httpReq.request(Main.githubAPIBaseURL + "repos/Ryhon0/VostokMods/releases", ["accept: application/vnd.github+json"])
	if err != OK:
		push_error("Failed to create mod loader releases request ", err)
		await checkModUpdates()
		return

	Main.StatusLabel.text = "Checking for updates"
	Main.showHttpProgress(httpReq)

	httpReq.request_completed.connect(injectorReleasesRequestCompleted)

func injectorReleasesRequestCompleted(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Failed to get mod loader releases")
		await checkModUpdates()
		return
	if response_code < 200 || response_code >= 300:
		push_error("Failed to get mod loader releases (HTTP code " + str(response_code) + ")")
		await checkModUpdates()
		return
	
	var json = JSON.parse_string(body.get_string_from_utf8())
	for r in json:
		if r["draft"]: continue
		if r["prerelease"] && !Main.config.autoUpdatePreRelease:
			continue
		var tag = r["tag_name"]

		var injectorAsset
		for a in r["assets"]:
			if a["name"] == "Injector.pck":
				injectorAsset = a
				break
		if !injectorAsset:
			continue

		print("Latest version: " + tag)
		if Main.version != tag:
			downloadLoaderUpdate(tag, injectorAsset)
		else: 
			await checkModUpdates()
		return

func downloadLoaderUpdate(tag, asset):
	var httpReq = HTTPRequest.new()
	add_child(httpReq)
	var err = httpReq.request(asset["browser_download_url"])
	if err != OK:
		Main.StatusLabel.text = "Failed to download mod loader update.\nCode " + str(err)
		get_tree().create_timer(2).timeout.connect(checkModUpdates)
		return

	Main.StatusLabel.text = "Downloading mod loader version " + tag
	Main.showHttpProgress(httpReq)

	httpReq.request_completed.connect(injectorFileDownloaded)

func injectorFileDownloaded(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Failed to download mod loader")
		Main.StatusLabel.text = "Failed to save mod loader, error " + str(FileAccess.get_open_error())
		get_tree().create_timer(2).timeout.connect(checkModUpdates)
		return
	if response_code < 200 || response_code >= 300:
		push_error("Failed to get mod loader releases (HTTP code " + str(response_code) + ")")
		Main.StatusLabel.text = "Failed to save mod loader, error " + str(FileAccess.get_open_error())
		get_tree().create_timer(2).timeout.connect(checkModUpdates)
		return

	var dir = ProjectSettings.globalize_path(".")
	var injectorPath = dir.path_join("Injector.pck")
	var deletemePath = dir.path_join("Injector.pck.deleteme")
	
	var err = DirAccess.rename_absolute(injectorPath, deletemePath)
	if err != OK:
		Main.StatusLabel.text = "Failed to move moad loader, error " + str(err)
		get_tree().create_timer(2).timeout.connect(checkModUpdates)
		return
	
	var f = FileAccess.open(injectorPath, FileAccess.WRITE)
	if !f:
		DirAccess.rename_absolute(deletemePath, injectorPath)
		Main.StatusLabel.text = "Failed to save mod loader, error " + str(FileAccess.get_open_error())
		get_tree().create_timer(2).timeout.connect(checkModUpdates)
		return
	f.store_buffer(body)
	f.close()

	var args = ["--main-pack", "Injector.pck", "--"]
	args.append(OS.get_cmdline_user_args())
	OS.create_process(OS.get_executable_path(), args, false)
	get_tree().quit()

func checkModUpdates():
	if !Main.config.allowModAutoUpdates:
		Main.Mods.loadMods()
		Main.launchOrShowConfig()
		return

	Main.StatusLabel.text = "Checking for mod updates"
	Main.Progress.value = 0
	Main.Progress.max_value = 1

	var updatableMods = []
	var mwsIds = []
	for mod in Main.Mods.mods:
		if mod.versionPinned: continue
		if mod.disabled && !Main.config.autoUpdateDisalbedMods:
			continue
			
		if mod.config.has_section_key("updates", "modworkshop"):
			updatableMods.append(mod)
			mwsIds.append(mod.config.get_value("updates", "modworkshop"))
	
	if !updatableMods.size():
		Main.launchOrShowConfig()
		return # No updatable mods found
	
	var idChunks = chunk(mwsIds, 100)
	var latestVersions = {}
	for ids in idChunks:
		var httpReq = HTTPRequest.new()
		add_child(httpReq)
		var err = httpReq.request("https://api.modworkshop.net/mods/versions",\
			["Content-Type: application/json", "Accept: application/json"],\
			HTTPClient.METHOD_GET, JSON.stringify({"mod_ids": ids}))
		if err != OK:
			push_error("Failed to create mod versions request ", str(err))
			continue
		Main.showHttpProgress(httpReq)
		var res = await httpReq.request_completed
		if res[0] != HTTPRequest.RESULT_SUCCESS:
			push_error("Mod versions request failed, code ", str(res[0]))
			continue
		var response_code = res[1]
		if response_code < 200 || response_code >= 300:
			push_error("Failed to get mod versions (HTTP code " + str(response_code) + ")")
			continue
		
		var versions = JSON.parse_string(res[3].get_string_from_utf8())
		if versions is Dictionary:
			latestVersions.merge(versions)
	
	for k in latestVersions.keys():
		var mod = updatableMods.filter(func(m): return m.config.get_value("updates", "modworkshop") == int(k))[0]
		
		var version = mod.config.get_value("mod", "version")
		var modName = mod.config.get_value("mod", "name")
		var latestVersion = latestVersions[k]

		if !latestVersion: # Version is empty
			push_warning("MWS mod ", k, " has an empty version!")
			continue

		var zip = mod.zipPath
		if FileAccess.file_exists(zip + ".zip"):
			zip += ".zip"
		elif FileAccess.file_exists(zip + ".zip.disabled"):
			zip += ".zip.disabled"

		if version == latestVersion: # Already up to date 
			print("MWS mod ", k , " is up to date")
			continue
		
		print("Updating MWS mod ", k , " to ", latestVersion)
		Main.StatusLabel.text = "Updating " + modName + "\n" + version + "→" + latestVersion
		
		var httpReq = HTTPRequest.new()
		add_child(httpReq)
		var err = httpReq.request("https://api.modworkshop.net/mods/"+str(k)+"/download")
		if err != OK:
			push_error("Failed to create mod download request ", str(err))
			continue
		Main.showHttpProgress(httpReq)
		var res = await httpReq.request_completed
		if res[0] != HTTPRequest.RESULT_SUCCESS:
			push_error("Mod download request failed, code ", str(res[0]))
			continue
		var response_code = res[1]
		if response_code < 200 || response_code >= 300:
			push_error("Failed to download mod (HTTP code " + str(response_code) + ")")
			continue

		err = OS.move_to_trash(zip)
		if err != OK:
			push_error("Failed to move mod to trash ", str(err))
			continue
		
		var f = FileAccess.open(zip, FileAccess.WRITE)
		if !f:
			push_error("Failed to open mod file ", FileAccess.get_open_error())
			continue
		
		f.store_buffer(res[3])
		f.close()
	
	Main.Mods.loadMods()
	Main.launchOrShowConfig()

func chunk(arr, size):
	var ret = []
	var i = 0
	var j = -1
	for el in arr:
		if i % size == 0:
			ret.push_back([])
			j += 1;
		ret[j].push_back(el)
		i += 1
	return ret
 GST2              ����                          8  RIFF0  WEBPVP8L$  /�`�H��Z���{���]��m-�.���4��Q�Z1䐻KP�۸K�>��m#IT|���o�q����K��;�m�lr�[��.[8�'S��.�af��/S�ON���4��\s=4���Dc�oM)W]1�|cqq�t����g�O~*�S���/>��q��£�̅3�2����2�rw���y���ږ��`��v�l�d8�㴑rw�=#�ț7�-����{��F�^�e~�w���{�wG��9��0'�2�A�����l�m�iϳ�s��sk�g�{�Y��/����> [remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://bcc6fhil26kqe"
path="res://.godot/imported/donate_icon.png-e44f274a86c8f4daccf0c652cf3d80a1.ctex"
metadata={
"vram_texture": false
}
         GST2   �   �      ����               � �        $	  RIFF	  WEBPVP8L	  /��_kێm�m��͊����}���k�Z3�633�3���ٮu��:��}�뮊"(`�v�m�߱��Jj۶m�6fo5g��P�
j�����&������t�.��Ԗ����2� ��＄� �t9-��C4�Κ��V�i��OL�e:�St�:+
n���@ x����^��)�`?��"�)&�l�9�h$M%�;!ZIs5T=_ �������b&�c�T4݄Sћ7�-�����Lԑ �+Fe7�=� 9��,�G�i��  ����.�&g�����S�7���hk��nD˩��)������j�F���� ��#&[�,�b6�clԵ=�lGV z��Lo����Pd
؏Q�eh�i� <�@ms����y&�2 (� ȑLm>^d�96��\��� ����阚�%�D�&�� �p���|���w]o-�ME�̍��/�������f�X'��@�Q��6|����E˭q)�	�q���5�~ރ����aNK��C�hʉ��s×_��x'�os�k��m@��Z��)�U�kncp���E��W���{��vFX���_ �3wgp/�l]M��zw���y|���dc0x�<Ak�9�K�R��� ��}ܕ?�<��u| �.�d.S���� �J��~�� ؾ���L�a��~�u�Ex���	n�d.�b�Y���&~��3���x��ё�Bl��(�`0x�w���s@*ru��2�c�)����0x4���J��*Jy��tI �dx������ȿ��/"�C\�Ǣ�*;�:������A*����\�w�S��c�x^��z~L��5X��e*Ѐ�O^�����	 7t_�2y��&��ϸ��`�A2�|�� j���T���G2�iE�bhC�i�x	Hm����e���v'E�� I6.�I:��J�
��̴�D� �ӝ+sS��߸2N�*G���������!B� ���"�$�
��R뭷T/At��6�D���ZN"�M�f˕�V��U�n��R���'D_R��q����~��䱔��#D��2��(�A�������T0�-l	i!� �h]��2�7P=�t���>���;�}R��C|G�*& ���G)��C�LC �l pILB�];�n��� 9�QQI�c�Ay� @�Z�y
 RULH��-��Ѻ�0 (Ҝ�Jx	 F�) ���7 @��	����P$-l XGM}�D\B4��H�c ��BL�2*�(C+{@��� Y@��R�2 �anBd�L���� `�Mzٌh+S��/�cIHkٙ"]hi]��=5�4D��(����OH}Fb��ж'$����lT]X�E��74h�6�*�R�%HQ��l@��i5��=U&ޫH���hz�1Y��;��t��gt�PcJU���-� ����`Z�E �9Z�Mx��T�4�ce�sO��m �;Z 5�R����""&�&2U�j�K�	����R6�Q�"���	�f�G��++"\D�+s�d��)OQ�[��?mR. �g,�D�H���rjD��)D�i�&@�Ś*%V=S���&V"2E^�(2��W�Q˒#D��TL��ǈ�����n�[F��:�E�g������Wuܪy�7�$-��Μ���A�e��)����%"��t�Ǘ��
 �+�hǂu1�Z����:Xs_8E� yj�)�K�x�E1R �GG:G���@=���C4���4T���� �t�z�lF�k�1j2���
Q�H9"KQ�ҧ�w��w�z���
�i-���HA�)�r�����,�ne�1鱸m�ڏ��1Y5����
SN?��!xW6�(G2E�^+8(W�� �lBI�P�֖R�ө��۠H�-('_�65C�ᔊ�|Jef����`�mDEkn-��x ���F���%|*2 �r��$�(��4� Cu�  �6`1R;�����Mep���_m���	&"!n��@�
 �{$���`7$�(JGs�%���x6�g��E�*SQ�`��pv���"�fTl�����R�2��g <�	 >ـ�ǘKM� �f-��6 ��P���sC �� �}��,-� ���� `=��Ԟ��oV`�Q� p+��-OU;��%D���h����GZ��u�T�>@�ݦj����)�M�?Z�1�G�e��ӂi�B������E��i��/�S��`[�����䩞�U�e�����+=�x3�?mV]�zp]B��D�`�1�-�6,��<U숝�[�ٲ��\�����e��J>�1����t�,���l�V_���    [remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://bthiqdf3jnb72"
path="res://.godot/imported/icon.png-487276ed1e3a0c39cad0279d744ee560.ctex"
metadata={
"vram_texture": false
}
                GST2            ����                        �$  RIFF�$  WEBPVP8L�$  /���(hۆ���� "&@��M�H�%hғm۲m�m�
�YD!��"bȊ[g���s�5��#<`۾Nɶm����;�E�NDP9Q��ƾ�n��;�ˎSN�TN9��V��n�&��}$J�l���g۶m۶m۶m۶m۶}�����kN����0mIP�U��~Ȳ��m��Z��s42�"�2�F�P�T����X�D��������.����I&Z{��<ED')�A"�t����_K�y������r�@��/����6�Q�M�R��d�e��~��Mc�?LJ��gW0�5�kf�eP^2s1n,�q��1�p�uP�i'��V�iw)�?0�=�⬼���p��\ǴJM��ۇi�� ���7��
t�v�1�o�;��OL{��8�W����8���V)�fw�bL���;n)f%�qQ��v�F4��7���7��cW��kL��	W�\�U
�;�0�D���$��I�Yw\gzLK�;��
LK&/!�#�0�k(eAy�X{�i�<���KD��U
�b��.�c�f���q�CV`�d4���q��&Ŭ�z� ��vj!�	S�iw�;�"���ioYCG�u�>l�Ǵ,��x�n��1�Bc�i�)��qL3�M����X�i�Q��Q��ں����s��꿛��*L�CވV���%�޲��\�Hym�Jô,��X[D���=L�
�A}k��4����"Dq��L���� Z}g�a�2h���_�c�@w����Tc�m�n5��_��0�k�"2��.�cZwho"���B�L�
���a�mq��:����p�X�i�� ��>�1n)��)�dfuStg�9K��E\-�`Z��2��io�aM�^9{M���i��Út�|�%���4�PXT8�&��$�a�^'Xպ_P�;b#�IF��^�f�1�²����~C�d�9��o
�Z�Ŵ$�yǬ��W!�����������3���k���R�`�F#X��P�� ��izQ�����s5l�4�pX��{2� ��f�-��M�59V�d�|-�қ9�,��'��**OQ�ؕ�V�i���O�D.�L$�OFq��S�i��aq+�c�g�N�՚U8��i����|��2�t�b	*�1M#V�
?W��@@|�e� �%LӋ���
���I8-���~�a�d,O� !�8	V���ָ������\W?�s:�җ9��J�?K�^a���Nڪô[d�f��Iv����,��>c�+j�F�w�ødM8���_�`@�SR�UX�:�T�`Z����kr���RϹ4 H�4�Hы��S�c�.��NL�����zNgH�X�T�*�0n��tZv��*�zZ�k�'����Uȥ8@|���fVhO�i7Ɇ�K�;?TaS�	1�J0�5��Ve�L��Cpۺ�"��7L������:=vac9DXz�i�B`H���|!�s���|W0M'�4�=:{�-?��$CaJ
�u�	G$vW��'�b�B�lh�ш�3����Ę0&����pIk��A=�� ��Hli��a�-.�$�/��b�KV0&�o=|!?2��e�c����+�i"65���?.�=O `�9��ksR��E.�c.-[���i:aP3�����$\\�.�a�h�R~��EO�Ր	�¤`c[��jql�aR�J:��:*��خ��b%�v�p��c{�
&嬺Q�s��3�O�0���\�1!s�V�!�ʟ��yJ�ñ�D��.`{��ψE86��UR?4��N���=\P1��3=�m+���|S�c�N6��5��9����^��a��E�=l}��E���~�B��hP�W��0f�gqt���F�:����	�'�3�u��L�ca�oanjWB3O���_ %RM� .����Ў��'g�ǰZu$)�/)��N��8.���T�� 2��v�V^�U��z.���y�27�2������P�ip��M����A&ς��}��\I[D�Nn2��g4�Mv �SG��B��-���®��."�A~e鼗J����C�?�����Tᗖ��*N���L�`�`�_Z����<�ڪĬ����ZFfz�Ia�@�{���3�����/:���0�,W���w�jN�~A{F��Gg�­�'��"~{���Y��_���m��;�d�v���Y7�P����IekUe���g���'�-�^�S9��)��qs� >�%���o}�tR�%do�����"��F��o�;P'/�
����P>Fz��؄��`d��}aOs��v��_� Iu�P�AP<��� &�͡��k|����0?��D��`%g���3�F�>M�Y���GwY�pBH�WN��m�|�^pi�B�G�˔Qh͔�c�&����t���3^o��Ec�;�y���3U&�̡���L1�A���|�3�����@C&���LG�cZ���J4�FKLf䎡���K&��0�
���[cM�J�44S�̶	I���|��j<�`��2������c|��RA)AM�#'��2�#�i������B0\�igd Sf�l�=�`�b#R�����6C�y�`�jն�|����1!�rf�%>&=��?)�ejh��avJ>X��^Y��#ߨ�MS���$��uP��vB;Z/d.�M<d�uj��D�����ls"w��w�`ݥ�K��Є�t�!4�9C6��=|�ޱ���23��t!�¼Y��>XY<���[��6��٧`�Y��F(���"0!7�;B&V�a�L�K'��P�L�?��v�^L�htu��&�(���0�5� m��5�:R�\�%�
Y��� ��`톾���aZ-�E*6mg��`%��������7
񇊥����`=����נ>!�ݬ�	T��2�����:�Pt�i�sT���q �B��Z碐$D� ?��-�{c1>X5ZBo�EL�ak�][c$��0���*�3]�`��(��Յ�8h�e�	- ��%����h��x��P�rB�X'�J%�7��\|�`A����}�$��(�/�|���
��EhE����h]&��B�>>XoXÒҪNr�<��9l�s�`��k�\e�%F���V�-���U.Z�qD��8����U/����M(w2^܇z��)l�~��h �kN*�
P6uS���k,̙�j�nTR�~O)�k,moU@,1��l�-��>X�k�f(BW����ۖP{��C����k.+�;J�>X����|i���Q[G�-q�|`}+�f:�
]`G���Zs����/a���#�bG�%=F]aD1E��:TI"aC�0�s%C:X���;aC5W��
���75��?�[�c����||����U��_�$V�h ���'|�n��1��+��V0����C|�^Rè���?�/���I�`?	.���++������v��U*Ƶ{5�aC��K+�j-�`C">f�ad���a*B=>X�ah}U�B�'l���`m���{���|aC����y�ҞHvR�����T�� t���tQ�����Jg�SX���j�)`K�+�7����]h��{j��V��Ti
_���j:���+l�	�����D÷do�gE$OLa��;S�e ��(����)��x���Z���GT  ,\�j�·e���+�D��v���1?1��K�쩗��(C��r�F�Eq��BL��^l�b�w栽�fXj�}��h�Fi��1G������ܵY4�8}Ŵ��L���/�����3V��d��Q�<Ŵ-�]��~'�Y�~s�Bv�D�W0�(��Z�7�3l�v�1`W5Nh3�������(�m����m&� ���s~u��f������r��b ����¬��n�.p]K'zL�C�-_�T�jJ��qU�Ư��
L{�����=l���L�����i��A^u���ir�pmuF,��{L+�*�Q��P�G�����+PH��zP���o �-l�`�8�\p�.@5G���6Z4�(W�v6`���E@��t*��FψS�h��T,u�ul��^g�hc�8�*[��\��r/0�y0��ц1����H[uX-Kh�n.a��g�Yi�k#@1֫Щ
�U<�}�Ѻ�cG�>{���z�7cT̯	g߰#�U�_�L��m� ����i�~%�%�rהT�O�Z��{�,���L�)K�gjiX�ł H&�6?kP
E2ױ���E@��<28�F�����
�8A���hc��$�" �>�"����a�:8B�@��"�,��^s+0�y�Z�Fk̐#:��5��C��E�~kT��¤'l4�S��!z�SCgkD3`�K�!�U�)��$�i�1�(k���?1[��*L{M����^dNa�4/U)�1��1_(r��b�/n ��!��*���N�VKİ2Q����c'��4 ��e�A�"��8��[�)�@C�]��S�ҿ�V��d�f
ݤ.���y���M�*
���fЮ�yL�_�L�W܊ �".&�;l�֘U�9��sF���7޵�B��T���K�h{-)ì+�if-O��q��}��C�\�*�^�Bt"a�5��%��ET���s���"�t�V�@ߖ!�mO�_�,�����pZL��|,TVIVg�V16�RiD	�u@3��g�V�i�C���!D�Ɋ��+k��m0F���-������OL��Q֒S��" ؽ�D�v��KS��@+ߢ�
Ӫ4�0��z���b;��`�90'����E|~�\��@����a���/a�Ť?au/(��0M2*�e�2U \i+�|a��H�.gp��߬ĸeP�o
��A�7R�%l����ayr9	�1�C-��ͯ��k�(6\(&Y,KА�Ѝ1�&Y��XiY�t��8�q�K(��7)�Z��B5��`��`�k���̞�a�N8z�0 4P�i߹@�8���K���`�=N8�e	 8��i%��V,c�.�
R_����َ�yB*Py�iZ��V5�P��*�AY�7�a�ya�3�\]@!���f�j5P�-�X��(�l���C3��t�A-��)��*��y�2a׍L��v'�6A-��=�"�2�^l��	�0���PKp	;�²��2��¾[��;�}�CYd;���s�]76���!�j�[�5��&��\��;�B���E/�՟�*�>f01�a�(��_� V�z\�V��H:L{��ީ��)x���j+�%�fG4���O�a�%�N�������j�3�0-�l���)�laԲ�וH�	�0�Z3�}{�e�:��dn�ʞrz��]L3����2��F5p���!\[�����4�X���aC�g,��R\]�voX�q+� �NX1�e29A����V�_LƸ#p%�¯*E��V�ٌz1��"?T�������j��Tbo�!D; ڨô��p���#��LzB-O9���RR�2� Ř��+B���B�IP�V���P8�B�}ôR�p
�Kx>��렖B
�V* ��T�V{8�:$H|0K��b��7�px)���~p�h� KQd=�f�~�Mu'��$z�P�r9��
��@�I��LxS3y}l��h~MZ�q,��j�djf;��[z��,�ȦZ�?c�FP��Z��O�{���R)��@Ks�t"���"��|J�L���4ZQ�e)I9�!P��W��ZW'�7GA��k%�b�<���{+�Q��Ti
Rr�^������[���]M	�h8�zfT�]F,1�2��.�ͤĵ�_@2
�$��Jg�?���
j���&A!E9K�P��AwȖ`��}� ��Y�&b�A8���g�1��a\_�Ց{;�z2�\';`r�$k��}���j�(��R(*�V�i�Y��$�9�.P4� �b���_�[[(�Ӿq���o
=��J����^co9<���L+g���Ӯ�X�wj����*�A!K�0�N[8��դ��*�&������G�7�h($s��z��45�(]�����6VX��IFA��7���\���X�,e�XR3K��b��'�'M��i�KDI$bG�م�0`o���R�8��3 ��&��0�{��#������[���cZ
�!�j�Z���DZ���,�[���
5Q�iil�:T��^��6�c�^�d�ٶ��;&�Z���I��~r�B^r1-�'�Sr)u�3��T�LC(d��Uh'��g�!Z��s�[�PH�>��u�������	�7l��D��yL����J�x�.�_L���@�-��+����<_����.�4����C� ڪ��	�1�\!;2 ��@��H�T�P��=��Bᴘ��%�Z��,�%_ ��.@�ebo�P�RL��疓�k�� ��MA{E������V���>��IGx���)�j��^aZ��px�;N\D���;��30���0ͤ'�_-$�@tQ �o9iS��1��GXgϻ]�>6�a=��*�[�X��̍����P��3Pi��2_[�5��\��D�Z�SV���7�I�먢2v��B^�V��
�P�io��q&e�T�1��-�l��#�7�U�iY��L�ki�}n�J���n�i� �H��*�4�B�`�F#8�n���E_�t��Fl���k0�
�<�4�H��&2-@2
	.c�h�J����*�Ƹyp/�T��1�4�v��������c..�`���kj(E�i���^r�{��
��`��p/Yy����B�0��/�K27�7��P��{L��.�C؛hR��iF�p1-���C�S�(R3{������)�{�B�0��b
S�͝�,Ћ)����%ۻ�.��:L{��%[pA�Cc��,ݴ��RPH�%�i��+�H�:S]�qQUb�<ǖ���$��&X��2���W�]�o�ɸ��O��Jl�}�dZ
'�Rl�䲈�Z\\2�7�"�CD�=|��������&I�����WP�����emgy�<�U� |���2E:�D��p`�#�M��Ց��$Y�_\^�g.6��݂��9n���@��l�l�aӑ{{D �gC���	Q��}� ?�g�!�3n~ao�|�n�gC��N���[�V���gC����؛IOx�����=g�Qln��Nj/��R��@��N�#,qP��:4�Y�ͭ�O)��C�O����Lu���I��2���i�؃�9��em�G%�B��À��P$�T�:��Ja�3�,Ζ����l!���"ZKYC�`�H9��h񖇽��֊J���"|�1?X�co��@��̜Rc�)�ML)���XQJ�����ܧ�����RhǱr{���J�1�Bc��׻=�C����l��C%;�):QЛZj]8TޠWܖ2�;�vb�htg��I�#�"�%d!}��I"/�A�2����A�O����F�oڪ��^SC���Vd�Cu8�Ҿ@z�'���_ܠ��&�"a	�0��q x���/�ebo�B��l�Je��`�0�8��zz��g؛NG(�#�;X��Zs�(xf��U�M4�E`T/X�RZD!�Y�?t���bs�ځ�
�aemH	��(���j6���G���]�8r���e�ECI�\!��ŤOd��K( ֪P|�D�aoOYB�au(� ��Q�YJ��er�z���BJ�v|� Fz��,�X �s!%,���KxytĸU5g�-�V�44���00AOy����6��������$��T@m����y���AK��O �&�<�H�����6CO%	mG06��)0k߁8l���A��'�:N��ucl&������0����S�s`�ߴP��}dM�%�BR�������z�@����Z��o;(��Ǝ.�o�>ao՚C[[�avB�3�s���',<�ތ�A_		�C�0���U���Eln<4v5A5��	#π�M����l��⡳��JR���g��.H��3����ڍ�_Sh�0���Q�+���I&��j@�'L=v5BɬhO���e�%�dCO�r���� �{���] �!�I|l���q�{����&�aBB�3`C/T){���-M���&g��f�I�C�F�J��0h4�`A�!3�Lyt��~XQH���0d��?��dK�����a��C@A?��`M����P��C ^O�;XTB�H|
J� X�̄\��cR�)0i&Z�aY�h� N$��)�|$f�aa�	/�c�6��1 W;����3	���4����K��jԊD����y\"�Ņ)�,`1�1�5�C��i<d���@7��<b�A ��X��꽔�d�|,�E!_X�MD���ĨD8�|����t8�.��U^F�� �¤;L(�ASV!� ���΂~��3��a����5�"��1��!�ΠJM�0�rY�v
'aL�2(O�&�B��i�I7��9�#eP�f��1+��q F��u*�4�4��&�y�E7�*�0)7U!d�`��K���p ����J`~
�%�m�������E7 �L�»*0����Τ=�Ά@�������}�<�O ��)��$�"R�P�p*ō ��+��.�%�X�5�ǒ��P�����:Q�r^%�: SK�@���UK��!T�p��H{=��jO(O�7��2 \}�k��|�Y�_갥�<�h��1�L&��,�/Nm���̀q̣��S���8�B�|��o
�|���o�pB����]U�W8�z� Qg@�#8G���1 =Uj�#Z	��9`f* �1.�(8��>��M�X��k8�|���� ��j��#��0�9 � �\C�����n(B@��1��ά�s��C "��R�@8�F2���vT���|�prcf�@m�GT8������� @S�ES"�A])� �nH\ Ȅ[�O�����(Ap�E�2�{I����X�����=w�t�1��-���0��"$�7OQ_X83��`q����h���^�HD�8,b�B?����4�l�po)�� G \]!/'C \^�)J�r�-�_v6Ү�l�a��Q�+\c�.1��O��|�V�M�(���,��I���p��tuZM��a���nӗ��Ջ W�Z;��r��m�@��\��?�)��=X�Mg��A&[b�c.9�]6Za����������3 [remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://wbaqykif8euy"
path="res://.godot/imported/icon.svg-218a8f2b3041327d8a5756f3a245f83b.ctex"
metadata={
"vram_texture": false
}
 extends Control
class_name InjectorMain

@export var VersionLabel : Label
@export var StatusLabel: Label
@export var Progress: ProgressBar

@export var LoadingScreen : Control
@export var ConfigScreen : Control

@export var SettingsPage : Control
@export var Mods : ModList
@export var Updater : AutoUpdater

var version

const configPath = "user://ModConfig.json"
class ModLoaderConfig:
	var customModDir : String = ""
	var startOnConfigScreen : bool = false
	var autoUpdatePreRelease : bool = false
	var allowAutoUpdate: bool = true
	var allowModAutoUpdates: bool = true
	var autoUpdateDisalbedMods: bool = false
var config : ModLoaderConfig = ModLoaderConfig.new()

func loadConfig():
	if !FileAccess.file_exists(configPath):
		return
	
	var f = FileAccess.open(configPath, FileAccess.READ)
	var obj = JSON.parse_string(f.get_as_text())
	config = ModLoaderConfig.new()
	if "customModDir" in obj:
		config.customModDir = obj["customModDir"]
	if "startOnConfigScreen" in obj:
		config.startOnConfigScreen = obj["startOnConfigScreen"]
	if "autoUpdatePreRelease" in obj:
		config.autoUpdatePreRelease = obj["autoUpdatePreRelease"]
	if "allowAutoUpdate" in obj:
		config.allowAutoUpdate = obj["allowAutoUpdate"]
	if "allowModAutoUpdates" in obj:
		config.allowModAutoUpdates = obj["allowModAutoUpdates"]
	if "autoUpdateDisalbedMods" in obj:
		config.autoUpdateDisalbedMods = obj["autoUpdateDisalbedMods"]
	SettingsPage.onLoaded()

func saveConfig():
	var jarr = {
		"customModDir": config.customModDir,
		"startOnConfigScreen": config.startOnConfigScreen,
		"autoUpdatePreRelease": config.autoUpdatePreRelease,
		"allowAutoUpdate": config.allowAutoUpdate,
		"allowModAutoUpdates": config.allowModAutoUpdates,
		"autoUpdateDisalbedMods": config.autoUpdateDisalbedMods
	}
	var jstr = JSON.stringify(jarr)
	var f = FileAccess.open(configPath, FileAccess.WRITE)
	f.store_string(jstr)
	f.flush()
	f.close()

const githubAPIBaseURL = "https://api.github.com/"

@onready var isWindows = OS.get_name() == "Windows"
@onready var pckToolFilename = "godotpcktool.exe" if isWindows else "godotpcktool"
@onready var pckToolPath = getGameDir() + "/" + pckToolFilename;
var pckName = "Public_Demo_2_v2.pck"

func shutdown():
	Progress.value = 1.0
	Progress.max_value = 1.0
	create_tween().tween_property(Progress, "value", 0.0, 3.0)
	await get_tree().create_timer(3.0).timeout
	get_tree().quit(1)

func showHttpProgress(httpReq: HTTPRequest):
	while httpReq.get_http_client_status() != HTTPClient.Status.STATUS_DISCONNECTED && \
		httpReq.get_http_client_status() != HTTPClient.Status.STATUS_CONNECTION_ERROR && \
		httpReq.get_http_client_status() != HTTPClient.Status.STATUS_TLS_HANDSHAKE_ERROR && \
		httpReq.get_http_client_status() != HTTPClient.Status.STATUS_CANT_CONNECT && \
		httpReq.get_http_client_status() != HTTPClient.Status.STATUS_CANT_RESOLVE:
			var bodySize = httpReq.get_body_size()
			if bodySize == -1:
				Progress.max_value = 1
				Progress.value = 0
			else:
				Progress.max_value = bodySize
				Progress.value = httpReq.get_downloaded_bytes()
			await RenderingServer.frame_pre_draw
	Progress.value = httpReq.get_body_size()

func getGameDir() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir() + "/"
	return OS.get_executable_path().get_base_dir() + "/"

func showLoadingScreen():
	LoadingScreen.show()
	ConfigScreen.hide()

func showConfigScreen():
	ConfigScreen.show()
	LoadingScreen.hide()

func _ready() -> void:
	loadConfig()

	var f = FileAccess.open("res://VM_VERSION", FileAccess.READ)
	version = f.get_as_text()
	VersionLabel.text = "Version " + version
	f.close()

	Mods.loadMods()
	showLoadingScreen()
	if !OS.has_feature("editor") and config.allowAutoUpdate:
		await Updater.checkInjectorUpdate()
	else:
		await Updater.checkModUpdates()

func launchOrShowConfig():
	if config.startOnConfigScreen:
		showConfigScreen()
	else:
		showLoadingScreen()
		launch()

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED, 0)

func getModsDir() -> String:
	if config.customModDir:
		return config.customModDir
	return getGameDir() + "/mods"

func openMods() -> void:
	OS.shell_show_in_file_manager(getModsDir())

func openUser() -> void:
	OS.shell_show_in_file_manager(OS.get_user_data_dir())

var isLaunching = false
var launchTimer : Timer
var launchTween : Tween
func launch() -> void:
	isLaunching = true
	StatusLabel.text = "Launching Road to Vostok
Press any key to abort or configure"
	var launchTime = 3.0
	launchTimer = Timer.new()
	add_child(launchTimer)
	launchTimer.timeout.connect(injectAndLaunch)
	launchTimer.start(launchTime)

	Progress.value = 0.0
	Progress.max_value = 1.0
	launchTween = create_tween()
	launchTween.tween_property(Progress, "value", 1.0, launchTime)

func _input(event: InputEvent) -> void:
	if !isLaunching:
		return
	if event.is_pressed():
		cancelLaunch()
		
func cancelLaunch() -> void:
	launchTimer.stop()
	launchTimer.queue_free()
	launchTimer = null

	launchTween.stop()
	launchTween = null

	isLaunching = false
	showConfigScreen()

func injectAndLaunch(modded: bool = true) -> void:
	saveConfig()
	showLoadingScreen()
	var useSubScriptInjector = true
	if useSubScriptInjector:
		startSubScriptInjector(modded)
	else: startPCKInjector(modded)

func startSubScriptInjector(modded: bool = true) -> void:
	# Load the game PCK to access the Perferences script
	if !ProjectSettings.load_resource_pack(getGameDir() + "/" + pckName):
		StatusLabel.text = "Failed to load " + pckName + ".
Update the injector or verify game files"
		shutdown()
		return
	
	var p = load("res://Scripts/Preferences.gd").Load()
	var script = load("res://Scripts/Preferences.gd")
	if modded:
		script = load("res://ModLoader/SubResourceEntryPoint.gd").duplicate()

	# set_script resets the state, so we need to copy and replicate it
	var state = {}
	for prop in p.get_property_list():
		if prop.usage != 4102: continue
		if prop.name == "loaderScript": continue
		state[prop.name] = p.get(prop.name)
	p.set_script(script)
	for k in state.keys():
		p.set(k, state[k])

	if modded:
		p.loaderScript = load("res://ModLoader/ModLoader.gd").duplicate()
	p.Save()

	var pckdir = getGameDir() + "/" + pckName
	if !FileAccess.file_exists(pckdir):
		StatusLabel.text = "PCK doesn't exist " + pckdir
		shutdown()
		return

	var modsDir = getModsDir()
	var args = ["--main-pack", pckdir, "--", "--mods-dir", modsDir]
	args.append(OS.get_cmdline_user_args())
	
	var pid = OS.create_process(OS.get_executable_path(), args, false)
	if pid == -1:
		StatusLabel.text = "Failed to start Road to Vostok"
		shutdown()
		return
	get_tree().quit()

func startPCKInjector(_modded: bool = true) -> void:
	if (!FileAccess.file_exists(pckToolPath)):
		StatusLabel.text = "Downloading GodotPCKTool"

		var httpReq = HTTPRequest.new()
		add_child(httpReq)
		var err = httpReq.request(githubAPIBaseURL + "repos/hhyyrylainen/GodotPckTool/releases/latest", ["accept: application/vnd.github+json"])
		if err != OK:
			StatusLabel.text = "Failed to create GodotPCKTool releases request"
			shutdown()
			return

		showHttpProgress(httpReq)
		httpReq.request_completed.connect(pckToolReleasesRequestCompleted)
	else:
		injectLoaderToPCK()

func pckToolReleasesRequestCompleted(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		StatusLabel.text = "Failed to get GodotPCKTool releases"
		shutdown()
		return
	if response_code < 200 || response_code >= 300:
		StatusLabel.text = "Failed to get GodotPCKTool releases (HTTP code " + str(response_code) + ")"
		shutdown()
		return
	
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var tag = json.data.tag_name
	var assets = json.data.assets

	var matchingAssets = assets.filter(func(a): return a.name == pckToolFilename)
	if matchingAssets.size() == 0:
		StatusLabel.text = "Could not find GodotPCKTool release asset " + pckToolFilename
		shutdown()
		return
	
	var asset = matchingAssets[0]

	StatusLabel.text = "Downloading " + pckToolFilename + " " + tag
	var httpReq = HTTPRequest.new()
	add_child(httpReq)
	var err = httpReq.request(asset.browser_download_url)
	if err != OK:
		StatusLabel.text = "Failed to create " + pckToolFilename + " " + tag + " request"
		shutdown()
		return
	
	showHttpProgress(httpReq)
	httpReq.request_completed.connect(pckToolDownloadRequestCompleted)

func pckToolDownloadRequestCompleted(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		StatusLabel.text = "Failed to download GodotPCKTool"
		shutdown()
		return
	if response_code < 200 || response_code >= 300:
		StatusLabel.text = "Failed to download GodotPCKTool (HTTP code " + str(response_code) + ")"
		shutdown()
		return

	print(pckToolPath)
	var fa = FileAccess.open(pckToolPath, FileAccess.WRITE_READ)
	fa.store_buffer(body)

	if !isWindows:
		if OS.execute("chmod", ["+x", pckToolPath]) != 0:
			StatusLabel.text = "Failed to mark " + pckToolPath + " as executable"
			shutdown()
			return
	
	injectLoaderToPCK()
		
func injectLoaderToPCK() -> void:
	StatusLabel.text = "Injecting mod loader"
	Progress.value = 0
	Progress.max_value = 1
	Progress.min_value = 0

	StatusLabel.text = "Checking hash"
	var pckPath = getGameDir() + "/" + pckName
	var pckHash = await hashPCK(pckPath)
	if !pckHash:
		StatusLabel.text = "Failed to calculate PCK hash"
		shutdown()
		return
	StatusLabel.text = "Hash = " + pckHash
	# TODO: append scripts, run PCK

func hashPCK(path):
	var CHUNK_SIZE = 33554432
	if not FileAccess.file_exists(path):
		return null
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	var file = FileAccess.open(path, FileAccess.READ)
	# Update the context after reading each chunk.

	Progress.min_value = 0
	Progress.max_value = file.get_length()
	Progress.value = file.get_position()

	while file.get_position() < file.get_length():
		Progress.value = file.get_position()
		Progress.max_value = file.get_length()

		var remaining = file.get_length() - file.get_position()
		ctx.update(file.get_buffer(min(remaining, CHUNK_SIZE)))
		await RenderingServer.frame_pre_draw
	Progress.value = file.get_length()
	
	# Get the computed hash.
	var res = ctx.finish()
	# Print the result as hex string and array.
	return res.hex_encode()

func openDonatePage():
	OS.shell_open("https://github.com/sponsors/Ryhon0")
         RSRC                    PackedScene            ��������                                                  ConfigScreen    VBoxContainer2    CenterContainer    VBoxContainer    VersionLabel    LoadingScreen    StatusLabel 	   Progress    TabContainer 	   Settings    Mods    AutoUpdater    ..    GridContainer    HBoxContainer    CustomModDirLine    ConfigStartCheckBox    LoaderUpdatesCheckBox    ModUpdatesCheckBox    DisabledModUpdatesCheckBox    ModListTree    resource_local_to_scene    resource_name 	   _bundled    script 	      Script    res://Main.gd ��������   Script    res://Settings.gd ��������   Script    res://ModList.gd ��������
   Texture2D    res://pin.svg T�T	XС(
   Texture2D    res://pin_disabled.svg >W?�9�X
   Texture2D    res://mws_logo_white.svg k���|
   Texture2D    res://icon.svg ('�Kau
   Texture2D    res://donate_icon.png T��'a&#   Script    res://AutoUpdater.gd ��������      local://PackedScene_wm3g6 �         PackedScene          	         names "   \      Main    layout_mode    anchors_preset    anchor_right    anchor_bottom    grow_horizontal    grow_vertical    script    VersionLabel    StatusLabel 	   Progress    LoadingScreen    ConfigScreen    SettingsPage    Mods    Updater    Control    visible    CenterContainer    VBoxContainer    text    horizontal_alignment    vertical_alignment    Label    custom_minimum_size 
   max_value    ProgressBar    HBoxContainer    TabContainer    size_flags_horizontal    current_tab 	   Settings    CustomModDirLine    StartOnConfigCheckBox    AllowAutoUpdateCheckBox    AllowModAutoUpdatesCheckBox    AutoUpdateDisabledModsCheckBox    metadata/_tab_index    ScrollContainer    size_flags_vertical    GridContainer &   theme_override_constants/h_separation    columns    placeholder_text 	   LineEdit    Button    Label2    ConfigStartCheckBox 	   CheckBox    Label3    LoaderUpdatesCheckBox    Label4    ModUpdatesCheckBox    Label5    DisabledModUpdatesCheckBox    List    PinIcon    PinIconDisabled    ModWorkshopLogo    ModListTree    column_titles_visible 
   hide_root    select_mode    scroll_horizontal_enabled    Tree    VBoxContainer2    TextureRect    texture    expand_mode    stretch_mode !   theme_override_colors/font_color    Button2    expand_icon 
   alignment    Button3 $   theme_override_font_sizes/font_size    AutoUpdater    Node    tabChanged    tab_changed    openModDirDialog    pressed    buttonPressed    button_clicked    titleClicked    column_title_clicked    itemEdited    item_edited    openDonatePage 	   openMods 	   openUser    injectAndLaunch    	   variants    ;                    �?                                                                                                    	                
                               Launching Road to Vostok 
     �C                                                                                                                                   Custom mod directory       Defaults to (game dir)/mods       ...       Start on config screen        Automatically update mod loader       Automatically update mods    #   Automatically update disabled mods                                                          
          C                     VostokMods Injector      �?  �?  �?   ?      Version x.x.x 
         @B
     �A                   Donate    
   Open mods       Open user://       Launch without mods 
         �B            Launch                         node_count    (         nodes     H  ��������       ����                                                @   	  @   
  @     @     @	     @
     @     @                     ����                                                              ����                       	   ����                                         
   ����                                       ����                                                        ����                                 &      ����                               @      @   !  @   "  @   #  @   $  @   %                       ����                '                 (   (   ����         )      *          	             ����                   	             ����                           ,       ����                +                 -   -   ����                   	          .   ����                   	       0   /   ����                   	          1   ����                   	       0   2   ����                   	          3   ����                    	       0   4   ����                   	          5   ����            !       	       0   6   ����                          &      ����	                  "      @   7  @#   8   $   9   %   :   &   %                 @   ;   ����                '       *   '   <   (   =   (   >      ?                    A   ����                                ����         '                        ����         '                  B   B   ����      )         C   *   D       E   +                    ����            ,                          ����         F   -      .                    -   G   ����      /         H   (                    ����                                       I                 B   B   ����      0         C   1   D      E   +                    ����            2                    ����             "       -   -   ����      /                   3       "       -   G   ����      /                   4              -   J   ����      /                   5              -   -   ����      6         K   7      8               M   L   ����      9      @:             conn_count    
         conns     G         O   N                    Q   P                    S   R                    U   T                    W   V                     Q   X              #       Q   Y              $       Q   Z              %       Q   [                &       Q   [                    node_paths              editable_instances              version             RSRC             extends ScrollContainer
class_name ModList

@export var Main: Control
@export var List: Tree

@export var PinIcon: Texture2D
@export var PinIconDisabled: Texture2D

@export var ModWorkshopLogo: Texture2D

var mods : Array[ModInfo] = []

class ModInfo:
	var zipPath : String
	var config : ConfigFile
	var disabled : bool
	var versionPinned : bool

	func makeDisabled(disable: bool):
		var from = zipPath + ".zip"
		var to = zipPath + ".zip"

		if disable: to += ".disabled"
		else: from += ".disabled"

		var err = DirAccess.rename_absolute(from, to)
		if err != OK:
			OS.alert("Could not move file " + from + " to " + to + ". Error " + err)
			return
		
		disabled = disable
	
	func pinVersion(pin: bool):
		if !pin:
			var err = DirAccess.remove_absolute(zipPath + ".dontupdate")
			if err != OK:
				OS.alert("Could remove file " + zipPath + ".dontupdate. Error " + err)
				return
			versionPinned = pin
		else:
			var f = FileAccess.open(zipPath + ".dontupdate", FileAccess.ModeFlags.WRITE)
			var err = FileAccess.get_open_error()

			if err != OK:
				OS.alert("Failed to create file " + zipPath + ".dontupdate. Error " + err)
				return

			f.store_string("")
			f.close()

			err = f.get_error()
			if err != OK:
				OS.alert("Failed to save file " + zipPath + ".dontupdate. Error " + err)
				return

			versionPinned = pin

const VERSION_COLUMN = 2
const VERSION_COLUMN_BUTTON_PIN = 0

const LINKS_CLOLUMN = 4

const ENABLED_COLUMN = 5

func _ready():
	List.set_column_title(0, "Name")
	List.set_column_title(1, "ID")
	List.set_column_title(VERSION_COLUMN, "Version")
	List.set_column_title(3, "File name")
	List.set_column_title(LINKS_CLOLUMN, "Links")
	List.set_column_title(ENABLED_COLUMN, "Enabled")

	for i in range(List.columns):
		List.set_column_expand(i, false)

	List.set_column_expand(0, true)
	List.set_column_custom_minimum_width(1, 175)
	List.set_column_custom_minimum_width(VERSION_COLUMN, 75)
	List.set_column_custom_minimum_width(3, 175)
	List.set_column_custom_minimum_width(LINKS_CLOLUMN, 90)

func loadMods():
	mods = []
	var modsdir = Main.getModsDir()

	List.clear()
	List.create_item()

	if !DirAccess.dir_exists_absolute(modsdir):
		DirAccess.make_dir_recursive_absolute(modsdir)
	var da = DirAccess.open(modsdir)
	for f in da.get_files():
		var zipname = f
		var disabled = false
		if f.ends_with(".zip.disabled"):
			zipname = f.substr(0, f.length() - ".zip.disabled".length())
			disabled = true
		elif f.ends_with(".zip"):
			zipname = f.substr(0, f.length() - ".zip".length())
			disabled = false
		else:
			continue
		var pinned = FileAccess.file_exists(modsdir.path_join(zipname) + ".dontupdate")
		
		var zr = ZIPReader.new()
		if zr.open(modsdir.path_join(f)) != OK:
			continue
		
		if !zr.file_exists("mod.txt"):
			continue
		
		var cfg = ConfigFile.new()
		cfg.parse(zr.read_file("mod.txt").get_string_from_utf8())
		zr.close()

		if !cfg.has_section_key("mod", "name") || !cfg.has_section_key("mod", "id") || !cfg.has_section_key("mod", "version"):
			continue

		var modname = cfg.get_value("mod", "name")
		var modid = cfg.get_value("mod", "id")
		var modver = cfg.get_value("mod", "version")

		var modi = ModInfo.new()
		modi.config = cfg
		modi.zipPath = modsdir.path_join(zipname)
		modi.disabled = disabled
		modi.versionPinned = pinned
		mods.append(modi)

		var li = List.create_item()
		li.set_meta("mod", modi)

		li.set_text(0, modname)
		li.set_text(1, modid)
		li.set_text(VERSION_COLUMN, modver)
		li.set_text(3, zipname)
		
		# Mod disalbed
		li.set_cell_mode(ENABLED_COLUMN, TreeItem.CELL_MODE_CHECK)
		li.set_checked(ENABLED_COLUMN, !disabled)
		li.set_editable(ENABLED_COLUMN, true)

		# Pin version
		li.add_button(VERSION_COLUMN, PinIcon if pinned else PinIconDisabled, VERSION_COLUMN_BUTTON_PIN, false, "Pin version")

		# Links
		var links : Array[String] = []
		if modi.config.has_section_key("updates", "modworkshop"):
			li.add_button(LINKS_CLOLUMN, ModWorkshopLogo, -1, false, "ModWorkshop")
			links.append("https://modworkshop.net/mod/" + str(modi.config.get_value("updates", "modworkshop")))
		li.set_meta("links", links)

func buttonPressed(item: TreeItem, column: int, button: int, mousebtn: int) -> void:
	if column == VERSION_COLUMN && button == VERSION_COLUMN_BUTTON_PIN && mousebtn == MOUSE_BUTTON_LEFT:
		var mod : ModInfo = item.get_meta("mod")
		mod.pinVersion(!mod.versionPinned)
		item.set_button(VERSION_COLUMN, VERSION_COLUMN_BUTTON_PIN, PinIcon if mod.versionPinned else PinIconDisabled)
		return
	if column == LINKS_CLOLUMN && mousebtn == MOUSE_BUTTON_LEFT:
		var links : Array[String] = item.get_meta("links")
		OS.shell_open(links[button])
		return

func itemEdited() -> void:
	if List.get_edited_column() == ENABLED_COLUMN:
		var item: TreeItem = List.get_edited()
		var modi: ModInfo = item.get_meta("mod")
		modi.makeDisabled(!modi.disabled)
		item.set_checked(ENABLED_COLUMN, !modi.disabled)

func titleClicked(col: int, mouse: int) -> void:
	if mouse != MOUSE_BUTTON_LEFT:
		return
	
	var root = List.get_root()
	var items = root.get_children()
	for i in items:
		root.remove_child(i)
	
	items.sort_custom(func(a: TreeItem, b: TreeItem) -> bool:
		if a.get_cell_mode(col) == TreeItem.CELL_MODE_STRING:
			return a.get_text(col).naturalnocasecmp_to(b.get_text(col)) < 0
		
		if a.get_cell_mode(col) == TreeItem.CELL_MODE_CHECK:
			return a.is_checked(col)
		return false)

	for i in items:
		root.add_child(i)
              GST2            ����                        �  RIFFx  WEBPVP8Lk  /�pI�"�}ܙp��K�I�������&�m'�����T���O̺�m۩� :D0���H�CFr�q��m��s>� ��ʶm;�W�Fg�rR�Jg۶m�{@1����؅c\�����+���D$��`�H�&�C!,��?^P
[���(�#�1�@�͈�:�_k;��׮D��H�@xE/�_ߔ{��C�ƸT���|J�v ���jk�)�{�C�cV~�t�0SP�0�� ���1����B"'��R���=Z	m����f�K
��@#n�!� >Q'������@ ��	� ΐ�l؀+�� ��1nq�M< P���>�@y�         [remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://d1c10pv53ai2x"
path="res://.godot/imported/mws_logo_white.svg-9e2febccbc8e44d82ff854ce9d86db63.ctex"
metadata={
"vram_texture": false
}
      GST2            ����                        v   RIFFn   WEBPVP8Lb   /��öm$��.%��2���ඃ�lcK�<���<� �o�W2Irv�I`;)"$��U�:m���S�CF6^$�-�WRy<�~���px��  [remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://bhyjjcpqm564o"
path="res://.godot/imported/pin.svg-8ffcbdbbbe25fd7c71979555d8a64c28.ctex"
metadata={
"vram_texture": false
}
 GST2            ����                        �   RIFF�   WEBPVP8L�   /��F�$Il#���fv��6�mUY�.�,�R���!r)�W�M �%G-��j�Jv�54Sk찔b�Qvr�""�rX�5�u���T�k-"�M^�] *�l#�i�'���c�Y��k�9�t5����"�9�{U�o�U0��� ""�v����                [remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://epy24urpfgha"
path="res://.godot/imported/pin_disabled.svg-e939da60381f48a090424b6e442ff96f.ctex"
metadata={
"vram_texture": false
}
         extends Control

@export var Main: Control
@export var CustomModDirLine: LineEdit
@export var StartOnConfigCheckBox: CheckBox
@export var AllowAutoUpdateCheckBox: CheckBox
@export var AllowModAutoUpdatesCheckBox: CheckBox
@export var AutoUpdateDisabledModsCheckBox: CheckBox

func _ready() -> void:
	CustomModDirLine.text_changed.connect(func(val): Main.config.customModDir = val; Main.saveConfig(); Main.Mods.loadMods())
	StartOnConfigCheckBox.toggled.connect(func(val): Main.config.startOnConfigScreen = val; Main.saveConfig())
	AllowAutoUpdateCheckBox.toggled.connect(func(val): Main.config.allowAutoUpdate = val; Main.saveConfig())
	AllowModAutoUpdatesCheckBox.toggled.connect(func(val): Main.config.allowModAutoUpdates = val; Main.saveConfig())
	AutoUpdateDisabledModsCheckBox.toggled.connect(func(val): Main.config.autoUpdateDisalbedMods = val; Main.saveConfig())

func openModDirDialog():
	var fd = FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	fd.show_hidden_files = true
	fd.dir_selected.connect(func(dir): CustomModDirLine.text = dir; Main.config.customModDir = dir; Main.Mods.loadMods())
	add_child(fd)
	fd.popup_centered_ratio()

func onLoaded():
	CustomModDirLine.text = Main.config.customModDir
	StartOnConfigCheckBox.button_pressed = Main.config.startOnConfigScreen
	AllowAutoUpdateCheckBox.button_pressed = Main.config.allowAutoUpdate
	AllowModAutoUpdatesCheckBox.button_pressed = Main.config.allowModAutoUpdates
	AutoUpdateDisabledModsCheckBox.button_pressed = Main.config.autoUpdateDisalbedMods
           0.4.2           [remap]

path="res://.godot/exported/133200997/export-bcb0d2eb5949c52b6a65bfe9de3e985b-Main.scn"
               list=Array[Dictionary]([{
"base": &"Node",
"class": &"AutoUpdater",
"icon": "",
"language": &"GDScript",
"path": "res://AutoUpdater.gd"
}, {
"base": &"Control",
"class": &"InjectorMain",
"icon": "",
"language": &"GDScript",
"path": "res://Main.gd"
}, {
"base": &"ScrollContainer",
"class": &"ModList",
"icon": "",
"language": &"GDScript",
"path": "res://ModList.gd"
}])
              �PNG

   IHDR   �   �   �>a�   	pHYs  �  �'��   tEXtSoftware www.inkscape.org��<  �IDATx��{��U�ǿ���EDETeM�������hC���(`��J��Iod�3e3Y*��M����xŰ�����(	�xW@�"8��cq��y�~���{��������Z{����~�^k��$Q�~�X��,�	P�(&@��� ��ny3,&@������y2m(v5���G�^��D�<+@�cp/6� ����)y0/&@uc'l�w�w6��@1�=����;���V���N47�e�W��P!V'�8בp*�۠���-�rG�B�X`S������@3���λ�bTFa�_)^^n�F�	P��#�K �}��)]7L؜��bPy�|������C�#�	PY����ן��,��WD�P�rhn>�(��6�]0maj�r��'G�m��1y��҉.Y��ƿ`�� N'���cd���1�7G�s�x�I� �t�� �����z_�b��$8X��C���/��B���`iB~�1�`�oۿ�Q���ؖ.8�-�'!�����=0Ma*���f��;Gٹ�)�[���)y }������m���	\��o#0���q����T$w�*i��KꝂ�/���2��(�O��U� n4 ��p�=���t�k����3���1)f^4��M��4��I�JI��A?A�V�3��g��@I�W+�*U� �8��S�;�?&��p�F��W��$�^?��@wG~R����I�QB�f`207�?��ݸ�����,��)z�,�V+���p;�$�����K�v�|����8�p9d���F��bo��s�o(7�
[���w�������z�c+Q��#�
`ڹ�I7�`o�r�v���3�`"Q��B��i�� =���ځ�\�������+�k���1��Q�yhľ��1��aBb^o�t�>�����T�����7ډ�q����+���NH���^��
0��|��'����>�N�Q��q8�>���pn�0]���}8x�W��V�#���� \�g���_�hQ��'2q�DfϞI��O�VΜ9����ҭWC��������1�X�v��q����ѣ� <X[�l	m謳���k����$���JJG��%�����K��}�Q��'��}Pz�!o7nT���h�=�(�,��ک�O@_��՞���O�^1�v���1y�����r��h޼y�Yc��3�8���퇌'bϡ	fd-���x_���uI�Vx�ǖlݺUC���}�jÆN��ƍ���-[�,X|���μ4 ��T�#���C�P�Gcc#��v k׮�{ʏ�Z�����0z�h�������G�*�� �x�P���:u*��30w�\6o�3%�����M���H_u��Ձ��.�6�ǌ#@]�v��o�����#G
P�^��v�Zy����?' WT��~Qg ��+Cۛ������߾=ٲe,^��	&ЧOy\����Xk�I�]ӿ
0O�vG���>�֭S�>}hԨQ��g̘�}��p�°>�W��3�-鍰__A,Q|���a��L��]�饗��ڪ�C�
�>�����0�^��:�'`g����d�QX�}���\���}$���̒%KX�b`{�6Aс58Nw�	��s��6�����1_��ѣ>|8 ����q��m'M
u
~ԙsY���$��5��� i�����a�g͚%@MMM<x� }��Q�9��V�0k�"�WW[%�����������\�RMMM�?@s����
y�Q��,�{a����������;v����ׯ�֯��|��N�F�I�q���܄��=�U8m�4��y ƏOϞ=}|�n�֢G���%
NeI�q+�1���vX�)雱�E�q�jmp �[�s�#_O`��;	[��$�k��$D���`O�O��Rl����ux�>�3��?���0����� ����3��"�et���#���[�����ۦ
Z�A`���|aK�<�>6���*�j�/�;G��9�ׁg13�W��D
��PI��_�A�}��S�HH�&�QO;�K�u�tm�(�xO��TmJR�c��J񐞑M�4l�t����=4J
U��M�>��Cͤ�OQ6+[���d��$�w�ge��G7I�zNh��刾�D�Si���N��z��$D9u\+��CI:JҚ���y!��T�' ����X���|x�lWL�2v��w"D��0�.j�z/���Y��<�����W���u�#dv���1�7I����!�]$M��l�tL�a2!2�7eBWK$
᷻���4�K�?cU��
�u<���>��������%�(�������q�_�J�	I�8�WH�/�}%=�K�?+|��d��rIz��#S4���>���z�$-w�k�t|I�=$=���J�!��*;!��$�»f����C�q��&:������l)w�L�~�\g�>P��K&�^�d�ķ$��;k.�
^<��%혱1� �)��s=yI����'���*�}9C�fO��X/s4��@�Wre��x7���7|�K��ȗl��m�$5{��p���c�*۰EҸ~wU'W��+94�)ߗy�i�����GOؒt�����f��5�\�l�gAז�bոtOa��1i:���m~3ӺB�u�)�t���~��k�L�Il�I�
�%̅�}O�)��M|9<��Kl�q3���m�,\��-���%AT��U����#0�&��{�bg����ܮVc�=k�I"+\�y#sh+�^��K]m�پ��˒��:��@� ,(�՘�LO_$�E�5	�`Фr�2�|�c�G��*����/,��voI7ƤyY�2��P���W�ښ���!�'m�f]IO���X��$]A�Z����`T"�
�8�zI�h����.��d���v������%�mt�V��ぽ�p�K0���.�.�SG��_{�\xGfHr��Q�D����u��
���U�N�$e=^f��af�%!tAl�4�ç���<t�=4u��*�ԷmX.wr��l�n�>#���4�QyЄ�1i�p�Q�m�+<4u��T����s��2{=��h-	h�ȟxh�Q's�Ȓ�V�Wų����r[�$�$� �:������9�?��R�)I�rSQxSv��F(ٞއ;� O�ۉ�y�PZ�^M))A��e�U�R��̢|�v��dm�p�lK>�7drJ�x��,G��a������	x�>�B�;�z\�6_ F�W����W��>,I�V]���Cw �aw���[�=a��lf��߂��M��N�J�����;#�����)|�s)?�� �ܖ�b2�gG~�N�G��+�w��P�	0;��Ǝ�q5�(��0��Yؕ�i|�-<D�K�^�F�\�G���X���b��lCGN ����`��p,�r�7{�3�B�`Q��	���}X�E9�Q���욡?�1�ӿe��)�2@O̝+��?�]�x,p���;���G�ws�F{O�.�1o���.��	u��=�4b�~�}�gGb����9��W���|L�U�hgU�jY�J:���[��2��(Ž�3��v~U��V����|i1�J̺-�7y��|�'�;�@�)��r,��U��i�ف��gf|\����H1�&)�	�VYtl��r����	}�QfI�9�N�|�!�7ˢ}�ez���\��l�<��
K����K�I�N)��tre�'��{��<���A�� nK�H%�J�\�f:��C��K�[�r!v4��tO��⾢�`��(ED�����ن7;��;5�(������[��S�m��8�>,%�p)�`[�b����y#r�[spM��#h>���k����;`��m�L�	�R��u���(��r�[S� ���ݟ�b��5�A'� nt��u�E�S�AN|k
�����݁�xx��	S�>�>�/Ӑ�5�M��,�R��Z�O@w�L!�:4�Pn�����yY˚�k<���MI�D��1'�,8ӑ���<k�	pW�m\I�.��ۑ7��a�遼�����R�[�����N�o�<8/�n�-�m���	QSw�E�ʁ�b�z���l~�ȿ���ޘ�*���OxT��~�;^Q~שt�?��]�>�s���z�D>���v*�\f�ZL��`F>`��?�V�l���G�@S�1/����_6Ն��b+�*U���	�-��[����3�۾=�����q�
6���n%IOVdl��q1���bZG_8���v.���'�lX���̏�:�;t.�<x� �(���'鋸��u��n�c��<(�!��n�����ӊ}6n�>iu���!ɹ�C0%Ѯ9��4f\��6삭0��F���υ�R��G҃!�c���n�aX�����@J$U�����E��o�w(�i�雱8�`�6���.f�iMA_ G�q6pv{�cH�l�u�L��ym����V��g�ul��0�lR��P�A� ��T�
PL�:G1��Yj�@G��    IEND�B`�          T��'a&#   res://donate_icon.png���h�J�3   res://icon.png('�Kau   res://icon.svgqG���?   res://Main.tscnk���|   res://mws_logo_white.svgT�T	XС(   res://pin.svg>W?�9�X   res://pin_disabled.svg             ECFG      application/config/name         Road to Vostok     application/run/main_scene         res://Main.tscn    application/config/features(   "         4.3    GL Compatibility        application/boot_splash/bg_color                    �?   application/boot_splash/image         res://icon.png      application/boot_splash/fullsize             application/config/icon         res://icon.png     dotnet/project/assembly_name         Road to Vostok  *   editor/naming/default_signal_callback_name$         on_{node_name}_{signal_name}2   editor/naming/default_signal_callback_to_self_name         on_{signal_name}   editor/naming/scene_name_casing             editor/naming/script_name_casing         #   rendering/renderer/rendering_method         gl_compatibility*   rendering/renderer/rendering_method.mobile         gl_compatibility2   rendering/environment/defaults/default_clear_color                    �?   vostokmods/is_injector                 