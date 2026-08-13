local mod = get_mod("scores")

mod.version = "1.1"

local DESCRIPTION_COLORS = {
	label = "255,170,32",
	text = "169,191,153",
}

local function mod_description(tagline, author_label, version_label)
	return tagline
		.. "\n\n{#color(" .. DESCRIPTION_COLORS.label .. ")}" .. author_label .. ": "
		.. "{#color(" .. DESCRIPTION_COLORS.text .. ")}u84n\n"
		.. "{#color(" .. DESCRIPTION_COLORS.label .. ")}" .. version_label .. ": "
		.. "{#color(" .. DESCRIPTION_COLORS.text .. ")}" .. mod.version
		.. "{#reset()}"
end

local function localized(en_text, zh_cn, ru, fr, es, de)
	return {
		en = en_text,
		["zh-cn"] = zh_cn,
		ru = ru,
		fr = fr,
		es = es,
		de = de,
	}
end

local UISettings = mod:original_require("scripts/settings/ui/ui_settings")

local function icon_from(settings, group, key)
	local icons = settings[group]
	return icons and icons[key] or nil
end

local title_symbol = UISettings.penance_font_icon
	or UISettings.penance_icon
	or icon_from(UISettings, "font_icons", "penance")
	or icon_from(UISettings, "ui_font_icons", "penance")
	or icon_from(UISettings, "menu_icons", "penance")
	or icon_from(UISettings, "hud_icons", "penance")
	or icon_from(UISettings, "font_icons", "achievement")
	or icon_from(UISettings, "ui_font_icons", "achievement")
	or icon_from(UISettings, "font_icons", "medal")
	or icon_from(UISettings, "ui_font_icons", "medal")
	or ""
local title_prefix = title_symbol ~= "" and "{#color(255,170,32)}"..title_symbol.." " or ""

mod:add_global_localize_strings({
	loc_scoreboard_history_view_display_name = localized("Scores History", "分数历史", "История счёта", "Historique des scores", "Historial de puntuaciones", "Punkteverlauf"),
	loc_scoreboard_save = localized("Save Scores", "保存分数", "Сохранить счёт", "Enregistrer les scores", "Guardar puntuaciones", "Punkte speichern"),
	loc_scoreboard_scan = localized("Scan Directory for files", "扫描目录中的文件", "Сканировать папку на наличие файлов", "Analyser le dossier pour trouver des fichiers", "Escanear directorio", "Verzeichnis nach Dateien durchsuchen"),
	loc_scoreboard_delete = localized("Delete Scores", "删除分数", "Удалить счёт", "Supprimer les scores", "Eliminar puntuaciones", "Punkte löschen"),
	loc_sg_enter_sg = localized("Training Grounds", "训练场", "Тренировочный полигон", "Terrain d'entraînement", "Campo de Entrenamiento", "Trainingsgelände"),
	loc_scoreboard_view_loadout = localized("View loadout", "查看配装", "Посмотреть снаряжение", "Voir l'équipement", "Ver equipamiento", "Ausrüstung ansehen"),
	loc_scoreboard_view_social_profile = localized("View social profile", "查看社交资料", "Открыть социальный профиль", "Voir le profil social", "Ver perfil social", "Sozialprofil ansehen"),
})

return {
	mod_title = localized(
		title_prefix.."{#color(255,64,0)}S{#color(255,112,0)}c{#color(255,160,0)}o{#color(255,208,0)}r{#color(255,246,80)}e{#color(255,255,128)}s{#reset()}",
		title_prefix.."{#color(255,64,0)}分{#color(255,160,0)}数{#reset()}",
		title_prefix.."{#color(255,64,0)}С{#color(255,112,0)}ч{#color(255,160,0)}ё{#color(255,208,0)}т{#reset()}",
		title_prefix.."{#color(255,64,0)}S{#color(255,112,0)}c{#color(255,160,0)}o{#color(255,208,0)}r{#color(255,246,80)}e{#color(255,255,128)}s{#reset()}",
		title_prefix.."{#color(255,64,0)}P{#color(255,112,0)}u{#color(255,160,0)}n{#color(255,208,0)}t{#color(255,246,80)}o{#color(255,255,128)}s{#reset()}",
		title_prefix.."{#color(255,64,0)}P{#color(255,112,0)}u{#color(255,160,0)}n{#color(255,208,0)}k{#color(255,246,80)}t{#color(255,255,128)}e{#reset()}"
	),
	mod_description = localized(
		mod_description("If you ain’t first, you’re last.", "Author", "Version"),
		mod_description("不当第一，就是最后。", "作者", "版本"),
		mod_description("Если ты не первый, ты последний.", "Автор", "Версия"),
		mod_description("Si tu n'es pas premier, tu es dernier.", "Auteur", "Version"),
		mod_description("Si no eres el primero, eres el último.", "Autor", "Versión"),
		mod_description("Wenn du nicht Erster bist, bist du Letzter.", "Autor", "Version")
	),
	scoreboard_title = localized("Scores", "分数", "СЧЁТ", "Scores", "Scores", "Punkte"),
	mod_history_view_title = localized("Scores History", "分数历史", "История счёта", "Historique des scores", "Historial de puntuaciones", "Punkteverlauf"),
	dev_mode = localized("Developer Mode", "开发者模式", "Режим разработчика", "Mode développeur", "Modo Desarrollador", "Entwicklermodus"),
	dev_mode_description = localized("Enables the developer-only keybind for opening Scores outside the end screen.", "启用仅开发者使用的按键绑定，用于在结算界面之外打开 Scores。", "Включает привязку клавиши только для разработчика, чтобы открывать Scores вне итогового экрана.", "Active le raccourci réservé aux développeurs pour ouvrir Scores en dehors de l'écran de fin.", "Habilita el atajo exclusivo de desarrollador para abrir Scores fuera de la pantalla final.", "Aktiviert die Entwickler-Tastenbelegung, um Scores außerhalb des Abschlussbildschirms zu öffnen."),
	tactical_overview = localized("Tactical overlay", "战术覆盖界面", "Тактическое наложение", "Superposition tactique", "Superposición táctica", "Taktische Einblendung"),
	tactical_overview_description = localized("Displays Scores on the tactical overlay during a mission", "在任务期间的战术覆盖界面上显示 Scores", "Показывает Scores в тактическом наложении во время миссии", "Affiche Scores sur la superposition tactique pendant une mission", "Muestra Scores en la superposición táctica durante la misión", "Zeigt Scores während einer Mission in der taktischen Einblendung an"),
	end_scoreboard_vertical_offset = localized(
		"Scores vertical offset",
		"结算分数垂直偏移",
		"Вертикальное смещение счёта",
		"Décalage vertical des scores",
		"Desplazamiento vertical de puntuaciones",
		"Vertikaler Versatz der Punkte"
	),
	end_scoreboard_vertical_offset_description = localized(
		"Moves Scores up or down from its default end screen position. Negative values move it up; positive values move it down.",
		"从默认结算界面位置上下移动分数界面。负值向上移动，正值向下移动。",
		"Сдвигает Scores вверх или вниз от стандартного положения на итоговом экране. Отрицательные значения двигают вверх, положительные - вниз.",
		"Déplace Scores vers le haut ou le bas depuis sa position par défaut à l'écran de fin. Les valeurs négatives le montent, les valeurs positives le descendent.",
		"Mueve Scores hacia arriba o abajo desde su posición predeterminada en la pantalla final. Los valores negativos lo suben; los positivos lo bajan.",
		"Verschiebt Scores auf dem Abschlussbildschirm nach oben oder unten. Negative Werte verschieben sie nach oben, positive nach unten."
	),
	announce_top_scores = localized(
		"Brag",
		"炫耀",
		"Похвастаться",
		"Se vanter",
		"Presumir",
		"Prahlen"
	),
	announce_top_scores_description = localized(
		"Sends a team chat message at the end screen when you uniquely lead Damage, Damage taken, or Objectives.",
		"当你在结算界面的伤害、承受伤害或目标中唯一领先时，向团队聊天发送一条消息。",
		"Отправляет сообщение в командный чат на итоговом экране, если вы единолично лидируете по урону, полученному урону или задачам.",
		"Envoie un message dans le chat d'équipe à l'écran de fin si vous êtes seul en tête pour les dégâts, les dégâts subis ou les objectifs.",
		"Envía un mensaje al chat del equipo en la pantalla final cuando lideras en solitario en daño, daño recibido u objetivos.",
		"Sendet auf dem Abschlussbildschirm eine Teamchat-Nachricht, wenn du allein bei Schaden, erlittenem Schaden oder Zielen führst."
	),
	open_scoreboard = localized("Open Scores", "打开分数", "Открыть счёт", "Ouvrir Scores", "Abrir Scores", "Scores öffnen"),
	open_scoreboard_description = localized("Opens or closes Scores when Developer Mode is enabled.", "开发者模式启用时打开或关闭分数界面。", "Открывает или закрывает Scores, когда включен режим разработчика.", "Ouvre ou ferme Scores lorsque le mode développeur est activé.", "Abre o cierra Scores cuando el Modo Desarrollador está activado.", "Öffnet oder schließt Scores, wenn der Entwicklermodus aktiviert ist."),
	developer_diagnostics = localized("Diagnostics", "诊断", "Диагностика", "Diagnostics", "Diagnóstico", "Diagnose"),
	developer_diagnostics_description = localized("Prints a compact Scores runtime diagnostic report when Developer Mode is enabled.", "在开发者模式启用时打印精简的 Scores 运行时诊断报告。", "Печатает краткий диагностический отчет Scores, когда включен режим разработчика.", "Affiche un rapport de diagnostic Scores compact lorsque le mode développeur est activé.", "Imprime un informe compacto de diagnóstico de Scores cuando el Modo Desarrollador está activado.", "Gibt einen kompakten Scores-Laufzeitdiagnosebericht aus, wenn der Entwicklermodus aktiviert ist."),
	open_scoreboard_history = localized("Open Scores history", "打开分数历史", "Открыть историю счёта", "Ouvrir l'historique Scores", "Abrir historial de Scores", "Scores-Verlauf öffnen"),
	open_scoreboard_history_description = localized("Opens the saved Scores history view.", "打开已保存的分数历史视图。", "Открывает сохраненную историю Scores.", "Ouvre l'historique Scores enregistré.", "Abre la vista del historial guardado de Scores.", "Öffnet die gespeicherte Scores-Verlaufsansicht."),
	history_save_mode = localized("Auto-save history", "自动保存历史记录", "Автосохранение истории", "Enregistrement automatique de l'historique", "Autoguardar historial", "Verlauf automatisch speichern"),
	history_save_mode_description = localized("Controls which end-screen Scores are automatically saved to history.", "控制哪些结算界面的分数会自动保存到历史记录。", "Настраивает, какие итоговые Scores автоматически сохраняются в историю.", "Contrôle quels Scores de l'écran de fin sont automatiquement enregistrés dans l'historique.", "Controla qué Scores de la pantalla final se guardan automáticamente en el historial.", "Legt fest, welche Scores vom Abschlussbildschirm automatisch im Verlauf gespeichert werden."),
	history_save_mode_none = localized("None", "无", "Нет", "Aucun", "Ninguno", "Keine"),
	history_save_mode_all = localized("All", "全部", "Все", "Tous", "Todos", "Alle"),
	history_save_mode_havoc = localized("Havoc only", "仅浩劫", "Только Havoc", "Havoc uniquement", "Solo Havoc", "Nur Havoc"),

	zero_values = localized("Zero values", "零值", "Нулевые значения", "Valeurs nulles", "Valores cero", "Nullwerte"),
	zero_values_description = localized("Controls how zero-value Scores cells are displayed.", "控制 Scores 中零值单元格的显示方式。", "Настраивает отображение ячеек Scores с нулевыми значениями.", "Contrôle l'affichage des cellules Scores à valeur nulle.", "Controla cómo se muestran las celdas con valor cero en Scores.", "Steuert, wie Scores-Zellen mit Nullwerten angezeigt werden."),
	zero_values_normal = localized("Normal", "正常", "Обычно", "Normal", "Normal", "Normal"),
	zero_values_hide = localized("Hidden", "隐藏", "Скрыто", "Masqué", "Oculto", "Ausgeblendet"),
	zero_values_dark = localized("Dark", "变暗", "Затемнено", "Sombre", "Oscuro", "Dunkel"),
	worst_values = localized("Worst values", "最低值", "Худшие значения", "Valeurs les plus faibles", "Peores valores", "Schlechteste Werte"),
	worst_values_description = localized("Controls whether the lowest value in each row is visually darkened.", "控制每行中的最低值是否在视觉上变暗。", "Настраивает, затемняется ли самое низкое значение в каждой строке.", "Contrôle si la valeur la plus faible de chaque ligne est assombrie.", "Controla si el valor más bajo de cada fila se muestra atenuado visualmente.", "Steuert, ob der niedrigste Wert jeder Zeile optisch abgedunkelt wird."),
	worst_values_normal = localized("Normal", "正常", "Обычно", "Normal", "Normal", "Normal"),
	worst_values_dark = localized("Dark", "变暗", "Затемнено", "Sombre", "Oscuro", "Dunkel"),
	row_backgrounds = localized("Row backgrounds", "行背景", "Фоны строк", "Arrière-plans des lignes", "Fondos de fila", "Zeilenhintergründe"),
	row_backgrounds_description = localized("On: automatically adds alternating row backgrounds when a section has many rows. Off: never shows row backgrounds.", "开启：当某个分区有很多行时，自动添加交替行背景。关闭：永不显示行背景。", "Вкл.: автоматически добавляет чередующиеся фоны строк, когда в разделе много строк. Выкл.: никогда не показывает фоны строк.", "Activé : ajoute automatiquement des arrière-plans alternés quand une section contient beaucoup de lignes. Désactivé : n'affiche jamais les arrière-plans des lignes.", "Activado: añade automáticamente fondos alternos cuando una sección tiene muchas filas. Desactivado: nunca muestra fondos de fila.", "Ein: Fügt automatisch abwechselnde Zeilenhintergründe hinzu, wenn ein Abschnitt viele Zeilen hat. Aus: Zeigt nie Zeilenhintergründe."),

	section_offense = localized("Offense", "进攻", "Атака", "Attaque", "Ofensivos", "Offensive"),
	section_defense = localized("Defense", "防御", "Защита", "Défense", "Defensivos", "Defensive"),
	section_support = localized("Teamwork", "团队协作", "Командная работа", "Travail d'équipe", "Trabajo en equipo", "Teamwork"),

	row_resources_collected = localized("Resources collected", "收集资源", "Собрано ресурсов", "Ressources collectées", "Recursos recogidos", "Gesammelte Ressourcen"),
	row_plasteel = localized("Plasteel collected", "收集塑钢", "Собрано пластали", "Plasteel collecté", "Plastiacero recogido", "Gesammeltes Plasteel"),
	row_diamantine = localized("Diamantine collected", "收集金刚晶", "Собрано диамантина", "Diamantine collectée", "Diamantina recogida", "Gesammeltes Diamantine"),
	small_plasteel = localized("Small Plasteel", "小份塑钢", "Малая пласталь", "Petit Plasteel", "Plastiacero pequeño", "Kleines Plasteel"),
	large_plasteel = localized("Large Plasteel", "大份塑钢", "Большая пласталь", "Grand Plasteel", "Plastiacero grande", "Großes Plasteel"),
	small_diamantine = localized("Small Diamantine", "小份金刚晶", "Малый диамантин", "Petite Diamantine", "Diamantina pequeña", "Kleine Diamantine"),
	large_diamantine = localized("Large Diamantine", "大份金刚晶", "Большой диамантин", "Grande Diamantine", "Diamantina grande", "Große Diamantine"),

	row_operated = localized("Objectives", "目标", "Задачи", "Objectifs", "Objetivos", "Ziele"),
	row_machinery_operated = localized("Machinery operated", "操作机械", "Механизмы использованы", "Machines utilisées", "Maquinaria operada", "Bediente Maschinen"),
	row_gadget_operated = localized("Gadget operated", "操作装置", "Устройства использованы", "Appareils utilisés", "Dispositivo operado", "Bediente Geräte"),
	row_rescues = localized("Revives", "救起", "Поднятия", "Réanimations", "Reanimaciones", "Wiederbelebungen"),
	row_revived_operative = localized("Revives", "救起", "Поднятия", "Réanimations", "Reanimaciones", "Wiederbelebungen"),
	row_rescued_operative = localized("Rescues", "营救", "Спасения", "Sauvetages", "Rescates", "Rettungen"),
	row_team_saves = localized("Saves", "救援", "Спасения", "Sauvetages", "Salvamentos", "Rettungsaktionen"),
	row_coherency_efficiency = localized("Coherency", "连携", "Сплоченность", "Cohésion", "Coherencia", "Kohärenz"),

	row_ammo_collected = localized("Ammo score", "弹药得分", "Счёт за боеприпасы", "Score de munitions", "Puntuación de munición", "Munitionswertung"),
	row_ammo_picked_up = localized("Picked up", "拾取", "Подобрано", "Ramassé", "Recogida", "Aufgehoben"),
	row_ammo_wasted = localized("Wasted", "浪费", "Потрачено впустую", "Gaspillé", "Desperdiciada", "Verschwendet"),
	row_ammo_small_picked_up = localized("Small", "小", "Малые", "Petit", "Pequeña", "Klein"),
	row_ammo_large_picked_up = localized("Large", "大", "Большие", "Grand", "Grande", "Groß"),
	row_ammo_crate_picked_up = localized("Crate", "箱子", "Ящик", "Caisse", "Caja", "Kiste"),

	row_damage_taken = localized("Damage taken", "承受伤害", "Получено урона", "Dégâts subis", "Daño recibido", "Erlittener Schaden"),
	row_times_downed = localized("Times downed", "倒地次数", "Падений", "Mises à terre", "Veces derribado", "Niedergänge"),
	row_deaths = localized("Deaths", "死亡次数", "Смертей", "Morts", "Muertes", "Tode"),
	row_times_disabled = localized("Times disabled", "被控制次数", "Выведен из строя", "Neutralisations subies", "Veces incapacitado", "Außer-Gefecht-Mal"),
	row_attacks_blocked = localized("Attacks blocked", "格挡攻击", "Атак заблокировано", "Attaques bloquées", "Ataques bloqueados", "Geblockte Angriffe"),
	row_heal_station_used = localized("Health station used", "使用医疗站", "Медстанций использовано", "Stations de soin utilisées", "Estación de salud usada", "Medicae-Stationen genutzt"),

	row_toggle_header = localized("Toggle stats", "切换统计", "Переключение статистики", "Activer les stats", "Activar estadísticas", "Statistiken umschalten"),
	group_row_toggles = localized("Toggle stats", "切换统计", "Переключение статистики", "Activer les stats", "Activar estadísticas", "Statistiken umschalten"),
	group_row_toggles_offense = localized("Offense", "进攻", "Атака", "Attaque", "Ofensivos", "Offensive"),
	group_row_toggles_defense = localized("Defense", "防御", "Защита", "Défense", "Defensivos", "Defensive"),
	group_row_toggles_support = localized("Teamwork", "团队协作", "Командная работа", "Travail d'équipe", "Trabajo en equipo", "Teamwork"),
	display_header = localized("Display", "显示", "Отображение", "Affichage", "Visualización", "Anzeige"),
	group_general = localized("General", "常规", "Общие", "Général", "General", "Allgemein"),
	group_display = localized("Display", "显示", "Отображение", "Affichage", "Visualización", "Anzeige"),
	stat_options_header = localized("Stat options", "统计选项", "Настройки статистики", "Options des statistiques", "Opciones de estadísticas", "Statistikoptionen"),
	group_stat_options = localized("Stat options", "统计选项", "Настройки статистики", "Options des statistiques", "Opciones de estadísticas", "Statistikoptionen"),
	scoreboard_history_header = localized("History", "历史记录", "История", "Historique", "Historial", "Verlauf"),
	group_scoreboard_history = localized("History", "历史记录", "История", "Historique", "Historial", "Verlauf"),
	layout_options_header = localized(
		"Layout",
		"布局",
		"Макет",
		"Disposition",
		"Diseño",
		"Layout"
	),
	group_layout = localized(
		"Layout",
		"布局",
		"Макет",
		"Disposition",
		"Diseño",
		"Layout"
	),
	developer_options_header = localized("Developer options", "开发者选项", "Параметры разработчика", "Options développeur", "Opciones de desarrollador", "Entwickleroptionen"),
	group_developer_options = localized("Developer options", "开发者选项", "Параметры разработчика", "Options développeur", "Opciones de desarrollador", "Entwickleroptionen"),
	show_attacks_blocked = localized("Attacks blocked", "格挡攻击", "Атак заблокировано", "Attaques bloquées", "Ataques bloqueados", "Geblockte Angriffe"),
	show_heal_station_used = localized("Health station used", "使用医疗站", "Медстанций использовано", "Stations de soin utilisées", "Estación de salud usada", "Medicae-Stationen genutzt"),
	show_coherency_efficiency = localized("Coherency", "连携", "Сплоченность", "Cohésion", "Coherencia", "Kohärenz"),
	show_ammo_collected = localized("Ammo score", "弹药得分", "Счёт за боеприпасы", "Score de munitions", "Puntuación de munición", "Munitionswertung"),
	ammo_efficiency = localized("Ammo efficiency", "弹药效率", "Эффективность боеприпасов", "Efficacité des munitions", "Eficiencia de munición", "Munitionseffizienz"),
	ammo_efficiency_description = localized("On: scores only the ammo actually gained from each pickup, rewarding efficient use. Off: scores every pickup at its full value (15/50/100), regardless of ammo gained, rewarding total pickups.", "开启：按拾取弹药的效率计分，效率最高者最佳。关闭：累加每个拾取物的完整百分比数值（15/50/100），拾取弹药最多者最佳。", "Вкл.: оценивает эффективность подбора боеприпасов; лучшим считается самый эффективный игрок. Выкл.: складывает полную процентную ценность каждого боеприпаса (15/50/100); лучшим считается собравший больше всего.", "Activé : mesure l’efficacité du ramassage ; la meilleure efficacité l’emporte. Désactivé : additionne la valeur totale en pourcentage de chaque paquet (15/50/100) ; le plus de munitions l’emporte.", "Activado: puntúa la eficiencia de recogida; la eficiencia más alta es la mejor. Desactivado: suma el valor porcentual completo de cada paquete (15/50/100); gana quien recoge más munición.", "Ein: Wertet die Aufnahmeeffizienz; die höchste Effizienz ist am besten. Aus: Addiert den vollen Prozentwert jedes Munitionspakets (15/50/100); die meiste Munition ist am besten."),
	show_weakspot_hit_percent = localized("Weakspot hit %%", "弱点命中 %%", "Попадания в уязвимые места %%", "Points faibles touchés %%", "Impactos en puntos débiles %%", "Schwachstellen-Treffer %%"),
	show_weakspot_hit_percent_description = localized("Shows weakspot hits as a percentage of damaging hits.", "将弱点命中显示为造成伤害命中的百分比。", "Показывает попадания в уязвимые места как процент от наносящих урон попаданий.", "Affiche les points faibles touchés en pourcentage des coups infligeant des dégâts.", "Muestra los impactos en puntos débiles como porcentaje de impactos que infligen daño.", "Zeigt Schwachstellentreffer als Prozentanteil der schadensverursachenden Treffer."),
	show_accuracy = localized("Ranged accuracy %%", "远程命中率 %%", "Точность дальнего боя %%", "Précision à distance %%", "Precisión a distancia %%", "Fernkampf-Trefferquote %%"),
	show_accuracy_description = localized("Shows observed ranged attacks that hit a minion as a percentage of observed ranged attacks fired.", "将观察到且命中敌人的远程攻击显示为观察到的远程攻击百分比。", "Показывает наблюдаемые дальние атаки, попавшие по врагу, как процент от наблюдаемых дальних атак.", "Affiche les attaques à distance observées qui touchent un ennemi en pourcentage des attaques à distance observées.", "Muestra los ataques a distancia observados que impactan a un enemigo como porcentaje de los ataques a distancia observados.", "Zeigt beobachtete Fernkampfangriffe, die einen Gegner treffen, als Prozentanteil der beobachteten Fernkampfangriffe."),
	show_resources_collected = localized("Resources collected", "收集资源", "Собрано ресурсов", "Ressources collectées", "Recursos recogidos", "Gesammelte Ressourcen"),
	show_revived_rescued = localized("Revives", "救起", "Поднятия", "Réanimations", "Reanimaciones", "Wiederbelebungen"),
	show_team_saves = localized("Saves", "救援", "Спасения", "Sauvetages", "Salvamentos", "Rettungsaktionen"),
	show_times_downed = localized("Times downed", "倒地次数", "Падений", "Mises à terre", "Veces derribado", "Niedergänge"),
	show_deaths = localized("Deaths", "死亡次数", "Смертей", "Morts", "Muertes", "Tode"),
	show_times_disabled = localized("Times disabled", "被控制次数", "Выведен из строя", "Neutralisations subies", "Veces incapacitado", "Außer-Gefecht-Mal"),
	show_weakspot_hits = localized("Weakspots hit", "命中弱点", "Слабые места", "Points faibles", "Puntos débiles", "Schwachstellen"),
	show_boss_damage_dealt = localized("Boss damage", "首领伤害", "Урон боссам", "Dégâts aux boss", "Daño a Jefes", "Boss-Schaden"),
	show_critical_hits = localized("Critical hit %%", "暴击 %%", "Критические попадания %%", "Coups critiques %%", "Impactos críticos %%", "Kritische Treffer %%"),
	show_critical_hits_description = localized("Shows critical hits as a percentage of damaging hits.", "将暴击显示为造成伤害命中的百分比。", "Показывает критические попадания как процент от наносящих урон попаданий.", "Affiche les coups critiques en pourcentage des coups infligeant des dégâts.", "Muestra los impactos críticos como porcentaje de impactos que infligen daño.", "Zeigt kritische Treffer als Prozentanteil der schadensverursachenden Treffer."),
	split_damage_dealt = localized("Include overkill", "包含溢出", "Учитывать избыточный урон", "Inclure l'excédent", "Incluir excedente", "Overkill einbeziehen"),
	split_damage_dealt_description = localized("Counts overkill damage in the Damage row.", "在伤害行中计入溢出伤害。", "Учитывает избыточный урон в строке урона.", "Compte les dégâts excédentaires dans la ligne Dégâts.", "Cuenta el daño sobrante en la fila de daño.", "Zählt Overkill-Schaden in der Schadenszeile mit."),
	split_resources_collected = localized("Split resources", "拆分资源", "Разделять ресурсы", "Séparer les ressources", "Separar recursos", "Ressourcen aufteilen"),
	split_resources_collected_description = localized("Shows Plasteel collected and Diamantine collected as separate rows.", "将收集的塑钢和金刚晶显示为单独的行。", "Показывает собранную пласталь и диамантин отдельными строками.", "Affiche le Plasteel collecté et la Diamantine collectée sur des lignes séparées.", "Muestra Plastiacero recogido y Diamantina recogida en filas separadas.", "Zeigt gesammeltes Plasteel und gesammeltes Diamantine als getrennte Zeilen an."),
	detailed_kill_split = localized("Split kill tiers", "拆分击杀层级", "Разделять уровни убийств", "Séparer les catégories d'éliminations", "Separar niveles de bajas", "Kill-Stufen aufteilen"),
	detailed_kill_split_description = localized("Splits kill stats between Swarmers, Elites, and Specials.", "将击杀统计拆分为杂兵、精英和特殊敌人。", "Разделяет статистику убийств на роевых врагов, элиту и специалистов.", "Sépare les statistiques d'éliminations entre grouilleurs, élites et spéciaux.", "Separa las estadísticas de bajas entre Horda, Élites y Especiales.", "Teilt Kill-Statistiken in Schwärmer, Eliten und Spezialisten auf."),
	show_melee_ranged_kills = localized(
		"Ranged / melee kills",
		"远程 / 近战击杀",
		"Убийства в дальнем / ближнем бою",
		"Éliminations à distance / en mêlée",
		"Bajas a distancia / cuerpo a cuerpo",
		"Fernkampf- / Nahkampf-Kills"
	),
	show_melee_ranged_kills_description = localized(
		"Displays separate Ranged kills and Melee kills rows.",
		"显示单独的远程击杀和近战击杀行。",
		"Показывает отдельные строки для убийств в дальнем и ближнем бою.",
		"Affiche des lignes séparées pour les éliminations à distance et en mêlée.",
		"Muestra filas separadas para bajas a distancia y bajas cuerpo a cuerpo.",
		"Zeigt separate Zeilen für Fernkampf-Kills und Nahkampf-Kills an."
	),
	opaque_scoreboard_backdrop = localized("Opaque background", "不透明背景", "Непрозрачный фон", "Fond opaque", "Fondo opaco", "Undurchsichtiger Hintergrund"),
	opaque_scoreboard_backdrop_description = localized("Adds a solid Scores background for readability.", "添加实心 Scores 背景以提高可读性。", "Добавляет сплошной фон Scores для лучшей читаемости.", "Ajoute un fond uni à Scores pour améliorer la lisibilité.", "Añade un fondo sólido a Scores para mejorar la legibilidad.", "Fügt zur besseren Lesbarkeit einen festen Scores-Hintergrund hinzu."),
	show_scoreboard_on_mission_end = localized("Mission end", "任务结束", "Конец миссии", "Fin de mission", "Final de misión", "Missionsende"),
	show_scoreboard_on_mission_end_description = localized("When enabled, Scores starts visible at mission end. When disabled, it starts hidden but stays loaded for the toggle keybind.", "启用时，任务结束时 Scores 默认显示。禁用时，它默认隐藏，但仍会加载以便按键切换。", "Если включено, Scores сразу виден в конце миссии. Если выключено, он скрыт, но остается загруженным для переключения клавишей.", "Si activé, Scores commence visible en fin de mission. Si désactivé, il commence masqué mais reste chargé pour le raccourci.", "Si está activado, Scores empieza visible al final de la misión. Si está desactivado, empieza oculto pero queda cargado para el atajo.", "Wenn aktiviert, startet Scores am Missionsende sichtbar. Wenn deaktiviert, startet es ausgeblendet, bleibt aber für die Taste geladen."),
	toggle_end_scoreboard_visibility = localized("Mission end toggle", "切换任务结束 Scores", "Переключить Scores в конце миссии", "Afficher/masquer Scores en fin de mission", "Alternar Scores al final de misión", "Scores am Missionsende umschalten"),
	toggle_end_scoreboard_visibility_description = localized("Shows or hides mission-end Scores without closing it. Unbound by default.", "显示或隐藏任务结束 Scores，但不会关闭它。默认未绑定按键。", "Показывает или скрывает Scores в конце миссии, не закрывая его. По умолчанию клавиша не назначена.", "Affiche ou masque Scores en fin de mission sans le fermer. Aucun raccourci par défaut.", "Muestra u oculta Scores al final de la misión sin cerrarlo. Sin tecla asignada por defecto.", "Zeigt oder verbirgt Scores am Missionsende, ohne es zu schließen. Standardmäßig nicht belegt."),
	player_name_display = localized("Player name", "玩家名称", "Имя игрока", "Nom du joueur", "Nombre del jugador", "Spielername"),
	player_name_display_description = localized("Controls whether Scores player headers show character names, account names, or both.", "控制 Scores 玩家标题显示角色名、账号名或两者。", "Настраивает, показывать ли в заголовках игроков Scores имя персонажа, имя аккаунта или оба.", "Détermine si les en-têtes des joueurs de Scores affichent le nom du personnage, le nom du compte ou les deux.", "Controla si los encabezados de jugadores de Scores muestran el nombre del personaje, el nombre de cuenta o ambos.", "Legt fest, ob die Scores-Spielerüberschriften Charakternamen, Kontonamen oder beides anzeigen."),
	player_name_display_character = localized("Character name", "角色名", "Имя персонажа", "Nom du personnage", "Nombre del personaje", "Charaktername"),
	player_name_display_account = localized("Account name", "账号名", "Имя аккаунта", "Nom du compte", "Nombre de cuenta", "Kontoname"),
	player_name_display_both = localized("Both", "两者", "Оба", "Les deux", "Ambos", "Beides"),
	hide_legacy_ui = localized("Hide legacy UI", "隐藏旧版界面", "Скрыть старый интерфейс", "Masquer l’ancienne interface", "Ocultar interfaz antigua", "Alte Benutzeroberfläche ausblenden"),
	hide_legacy_ui_description = localized("Hides the native mission circumstance and expedition currency widgets from the tactical overlay to reduce overlap with Scores.", "隐藏战术覆盖界面中的原生任务状况和远征货币组件，以减少与 Scores 的重叠。", "Скрывает стандартные элементы условий миссии и валюты экспедиции в тактическом интерфейсе, чтобы они не перекрывали Scores.", "Masque les widgets natifs de condition de mission et de monnaie d’expédition dans l’interface tactique afin de limiter le chevauchement avec Scores.", "Oculta los widgets nativos de circunstancia de misión y moneda de expedición de la interfaz táctica para evitar que se solapen con Scores.", "Blendet die nativen Widgets für Missionsumstände und Expeditionswährung in der taktischen Übersicht aus, damit sie sich nicht mit Scores überschneiden."),
	me_first = localized("Me first", "我优先", "Я первый", "Moi d'abord", "Yo primero", "Ich zuerst"),
	me_first_description = localized("Displays your player column first. Turn this off to keep the game's original player order.", "优先显示你的玩家列。关闭后保留游戏原始玩家顺序。", "Показывает ваш столбец игрока первым. Отключите, чтобы сохранить исходный порядок игроков игры.", "Affiche votre colonne de joueur en premier. Désactivez cette option pour conserver l'ordre original des joueurs du jeu.", "Muestra primero tu columna de jugador. Desactívalo para conservar el orden original de jugadores del juego.", "Zeigt deine Spielerspalte zuerst an. Deaktiviere dies, um die ursprüngliche Spielerreihenfolge des Spiels beizubehalten."),
	top_score_announcement_prefix = localized("[Scores]", "[Scores]", "[Scores]", "[Scores]", "[Scores]", "[Scores]"),
	top_score_announcement_damage = localized(
		"%%s got top Damage of %%s.",
		"%%s 造成了最高伤害：%%s。",
		"%%s нанес(ла) больше всего урона: %%s.",
		"%%s a infligé le plus de dégâts : %%s.",
		"%%s infligió el mayor daño: %%s.",
		"%%s hat den meisten Schaden verursacht: %%s."
	),
	top_score_announcement_damage_taken = localized(
		"%%s took the least damage with %%s.",
		"%%s 承受伤害最少：%%s。",
		"%%s получил(а) меньше всего урона: %%s.",
		"%%s a subi le moins de dégâts : %%s.",
		"%%s recibió el menor daño: %%s.",
		"%%s hat den wenigsten Schaden erlitten: %%s."
	),
	top_score_announcement_objectives = localized(
		"%%s completed the most Objectives with %%s.",
		"%%s 完成的目标最多：%%s。",
		"%%s выполнил(а) больше всего задач: %%s.",
		"%%s a rempli le plus d'objectifs : %%s.",
		"%%s completó más objetivos: %%s.",
		"%%s hat die meisten Ziele abgeschlossen: %%s."
	),
	show_lesser_enemies = localized("Swarmers killed", "击杀杂兵", "Убито роящихся врагов", "Grouilleurs éliminés", "Bajas de Horda", "Schwärmer getötet"),
	show_melee_ranged_threats = localized("Elite threats", "精英威胁", "Элитные угрозы", "Menaces d'élite", "Amenazas élite", "Elite-Bedrohungen"),
	show_special_threats = localized("Specials killed", "击杀特殊敌人", "Убито специалистов", "Spéciaux éliminés", "Especiales eliminados", "Spezialisten getötet"),

	row_damage_dealt = localized("Damage", "伤害", "Урон", "Dégâts", "Daño", "Schaden"),
	row_damage_dealt_1 = localized("Actual / overkill damage dealt", "实际 / 溢出造成伤害", "Фактический / избыточный нанесенный урон", "Dégâts infligés réels / excédentaires", "Daño real / excedente", "Verursachter tatsächlicher / Overkill-Schaden"),
	row_damage_dealt_2 = localized("Damage", "伤害", "Урон", "Dégâts", "Daño", "Schaden"),
	row_actual_damage_dealt = localized("Damage", "伤害", "Урон", "Dégâts", "Daño", "Schaden"),
	row_actual_damage_dealt_1 = localized("Damage", "伤害", "Урон", "Dégâts", "Daño", "Schaden"),
	row_actual_damage_dealt_2 = localized("Damage", "伤害", "Урон", "Dégâts", "Daño", "Schaden"),
	row_overkill_damage_dealt = localized("Overkill damage dealt", "造成溢出伤害", "Нанесенный избыточный урон", "Dégâts excédentaires infligés", "Daño excedente", "Verursachter Overkill-Schaden"),
	row_boss_damage_dealt = localized("Boss damage", "首领伤害", "Урон боссам", "Dégâts aux boss", "Daño a Jefes", "Boss-Schaden"),
	row_weakspot_hits = localized("Weakspots hit", "命中弱点", "Попаданий в уязвимые места", "Points faibles touchés", "Impactos en puntos débiles", "Schwachstellen getroffen"),
	row_weakspot_hit_percent = localized("Weakspot hit", "弱点命中", "Попадания в уязвимые места", "Points faibles touchés", "Impactos en puntos débiles", "Schwachstellen-Treffer"),
	row_damaging_hits = localized("Damaging hits", "造成伤害的命中", "Попадания с уроном", "Coups infligeant des dégâts", "Impactos con daño", "Schadensverursachende Treffer"),
	row_weakspot_damaging_hits = localized("Weakspot damaging hits", "造成伤害的弱点命中", "Попадания в уязвимые места с уроном", "Coups aux points faibles infligeant des dégâts", "Impactos en puntos débiles con daño", "Schadensverursachende Schwachstellentreffer"),
	row_accuracy = localized("Ranged accuracy", "远程命中率", "Точность дальнего боя", "Précision à distance", "Precisión a distancia", "Fernkampf-Trefferquote"),
	row_ranged_shots_fired = localized("Ranged shots fired", "远程射击次数", "Дальние выстрелы", "Tirs à distance effectués", "Disparos a distancia realizados", "Fernkampfschüsse abgegeben"),
	row_ranged_shots_hit = localized("Ranged shots hit", "远程命中次数", "Дальние попадания", "Tirs à distance réussis", "Disparos a distancia acertados", "Fernkampfschüsse getroffen"),
	row_critical_hits = localized("Critical hit", "暴击", "Критические попадания", "Coups critiques", "Impactos críticos", "Kritische Treffer"),
	row_critical_damaging_hits = localized("Critical damaging hits", "造成伤害的暴击", "Критические попадания с уроном", "Coups critiques infligeant des dégâts", "Impactos críticos con daño", "Schadensverursachende kritische Treffer"),

	row_kills = localized("Kills", "击杀", "Убийства", "Éliminations", "Bajas Totales", "Kills"),
	row_ranged_kills = localized(
		"Ranged kills",
		"远程击杀",
		"Убийства в дальнем бою",
		"Éliminations à distance",
		"Bajas a distancia",
		"Fernkampf-Kills"
	),
	row_melee_kills = localized(
		"Melee kills",
		"近战击杀",
		"Убийства в ближнем бою",
		"Éliminations en mêlée",
		"Bajas cuerpo a cuerpo",
		"Nahkampf-Kills"
	),
	row_lesser_enemies = localized("Swarmers killed", "击杀杂兵", "Убито роящихся врагов", "Grouilleurs éliminés", "Bajas de Horda", "Schwärmer getötet"),
	row_melee_ranged_threats = localized("Elites killed", "击杀精英", "Убито элитных врагов", "Élites éliminées", "Bajas de Élites", "Eliten getötet"),
	row_melee_threats = localized("Melee elites killed", "击杀近战精英", "Убито элиты ближнего боя", "Élites de mêlée éliminées", "Bajas de Élites cuerpo a cuerpo", "Nahkampf-Eliten getötet"),
	row_ranged_threats = localized("Ranged elites killed", "击杀远程精英", "Убито элиты дальнего боя", "Élites à distance éliminées", "Bajas de Élites a distancia", "Fernkampf-Eliten getötet"),
	row_special_threats = localized("Specials killed", "击杀特殊敌人", "Убито специалистов", "Spéciaux éliminés", "Bajas de Especiales", "Spezialisten getötet"),
}
