using System;
using System.Collections.Generic;
using System.Globalization;

namespace SwitchDeck
{
    internal static class L
    {
        public static string Lang = "en";

        private static readonly Dictionary<string, string[]> texts = new Dictionary<string, string[]>
        {
            { "tabSwitches", new[] { "Switches", "Switchs" } },
            { "tabTemplates", new[] { "Templates", "Modèles" } },
            { "tabDeploy", new[] { "Deploy", "Déployer" } },
            { "tabHistory", new[] { "History", "Historique" } },
            { "tabSettings", new[] { "Settings", "Paramètres" } },
            { "tabAbout", new[] { "About", "À propos" } },
            { "tabConnection", new[] { "Connection", "Connexion" } },
            { "tabPorts", new[] { "Ports", "Ports" } },

            { "ok", new[] { "OK", "OK" } },
            { "cancel", new[] { "Cancel", "Annuler" } },
            { "save", new[] { "Save", "Enregistrer" } },
            { "saved", new[] { "Saved", "Enregistré" } },
            { "add", new[] { "Add", "Ajouter" } },
            { "edit", new[] { "Edit", "Modifier" } },
            { "delete", new[] { "Delete", "Supprimer" } },
            { "duplicate", new[] { "Duplicate", "Dupliquer" } },
            { "copy", new[] { "Copy", "Copier" } },
            { "paste", new[] { "Paste", "Coller" } },
            { "copied", new[] { "Copied to the clipboard", "Copié dans le presse-papiers" } },
            { "selectAll", new[] { "Select all", "Tout sélectionner" } },
            { "copyAll", new[] { "Copy everything", "Tout copier" } },
            { "clearScreen", new[] { "Clear the screen", "Effacer l'écran" } },
            { "copyOf", new[] { "{0} copy", "{0} copie" } },
            { "later", new[] { "Not now", "Plus tard" } },
            { "replace", new[] { "Replace", "Remplacer" } },
            { "keepMine", new[] { "Keep my list", "Garder ma liste" } },
            { "discard", new[] { "Discard changes", "Abandonner" } },
            { "keepEditing", new[] { "Keep editing", "Continuer" } },
            { "stop", new[] { "Stop", "Arrêter" } },
            { "stopping", new[] { "Stopping", "Arrêt en cours" } },
            { "stopped", new[] { "Stopped by you", "Arrêté par vous" } },
            { "all", new[] { "All", "Tous" } },
            { "none", new[] { "None", "Aucun" } },
            { "trust", new[] { "Trust and connect", "Faire confiance" } },
            { "quit", new[] { "Close SwitchDeck", "Fermer SwitchDeck" } },
            { "quitTitle", new[] { "Close SwitchDeck?", "Fermer SwitchDeck ?" } },
            { "quitText", new[] { "{0} connection(s) are still open. They will be closed.", "{0} connexion(s) encore ouverte(s). Elles seront fermées." } },
            { "oops", new[] { "Something went wrong", "Un problème est survenu" } },
            { "today", new[] { "Today", "Aujourd'hui" } },
            { "yesterday", new[] { "Yesterday", "Hier" } },
            { "noMatch", new[] { "Nothing matches", "Aucun résultat" } },

            { "searchSwitches", new[] { "Search switches", "Rechercher un switch" } },
            { "addSwitch", new[] { "Add a switch", "Ajouter un switch" } },
            { "addSwitchShort", new[] { "Add switch", "Ajouter" } },
            { "editSwitch", new[] { "Edit {0}", "Modifier {0}" } },
            { "editSwitchShort", new[] { "Edit this switch", "Modifier ce switch" } },
            { "noSwitchesTitle", new[] { "No switches yet", "Aucun switch" } },
            { "noSwitchesText", new[] { "Add your first switch to get started.", "Ajoutez votre premier switch pour commencer." } },
            { "noGroup", new[] { "Other", "Autres" } },
            { "welcomeTitle", new[] { "Welcome to SwitchDeck", "Bienvenue dans SwitchDeck" } },
            { "welcomeText", new[] { "Add a switch, then connect to it or deploy a template on its ports.", "Ajoutez un switch, puis connectez-vous ou déployez un modèle sur ses ports." } },
            { "connect", new[] { "Connect", "Connexion" } },
            { "openTerminal", new[] { "Open terminal", "Ouvrir le terminal" } },
            { "disconnect", new[] { "Disconnect", "Déconnecter" } },
            { "reconnect", new[] { "Reconnect", "Reconnecter" } },
            { "overview", new[] { "Overview", "Vue d'ensemble" } },
            { "neverConnected", new[] { "Never connected", "Jamais connecté" } },
            { "lastConnected", new[] { "Last connected {0}", "Dernière connexion le {0}" } },
            { "legacyChip", new[] { "Legacy SSH", "SSH ancien" } },
            { "portsTitle", new[] { "Ports", "Ports" } },
            { "portsNone", new[] { "No ports registered yet", "Aucun port enregistré" } },
            { "portsSummary", new[] { "{0} ports   {1}", "{0} ports   {1}" } },
            { "portsShort", new[] { "{0} ports", "{0} ports" } },
            { "statusAt", new[] { "Status read at {0}", "État lu à {0}" } },
            { "detectPorts", new[] { "Detect ports", "Détecter les ports" } },
            { "refreshStatus", new[] { "Refresh status", "Actualiser l'état" } },
            { "editPorts", new[] { "Edit ports", "Modifier les ports" } },
            { "deploySelected", new[] { "Deploy", "Déployer" } },
            { "deployCount", new[] { "Deploy on {0} ports", "Déployer sur {0} ports" } },
            { "plateHint", new[] { "Click ports to select them, then deploy a template on them.", "Cliquez sur des ports pour les sélectionner, puis déployez un modèle." } },
            { "noPortsTitle", new[] { "No ports yet", "Aucun port" } },
            { "noPortsText", new[] { "SwitchDeck can read them from the switch, or you can type them yourself.", "SwitchDeck peut les lire sur le switch, ou vous pouvez les saisir vous-même." } },
            { "addManually", new[] { "Add them myself", "Les saisir moi-même" } },
            { "deployHere", new[] { "Deploy here", "Déployer ici" } },
            { "sendBreak", new[] { "Send break", "Envoyer un break" } },
            { "openSessionLogs", new[] { "Open session logs", "Ouvrir les journaux de session" } },
            { "closeSession", new[] { "Close this session", "Fermer la session" } },
            { "busyWait", new[] { "SwitchDeck is still typing on this switch. Wait or stop it first.", "SwitchDeck écrit encore sur ce switch. Attendez ou arrêtez-le." } },
            { "stateConnected", new[] { "Connected", "Connecté" } },
            { "stateConnecting", new[] { "Connecting", "Connexion" } },
            { "stateClosed", new[] { "Disconnected", "Déconnecté" } },
            { "modeUser", new[] { "User mode", "Mode utilisateur" } },
            { "modeEnable", new[] { "Privileged mode", "Mode privilégié" } },
            { "modeConfig", new[] { "Configuration mode", "Mode configuration" } },
            { "typing", new[] { "SwitchDeck is typing.", "SwitchDeck écrit." } },
            { "switchAdded", new[] { "{0} added", "{0} ajouté" } },
            { "switchDeleted", new[] { "{0} deleted", "{0} supprimé" } },
            { "deleteSwitch", new[] { "Delete this switch?", "Supprimer ce switch ?" } },
            { "deleteSwitchText", new[] { "{0} and its saved ports will be removed from SwitchDeck. Nothing changes on the switch itself.", "{0} et ses ports enregistrés seront retirés de SwitchDeck. Rien ne change sur le switch." } },

            { "hostKeyTitle", new[] { "New switch key", "Nouvelle clé de switch" } },
            { "hostKeyText", new[] { "This is the first SSH connection to {0}. Check that its key fingerprint is the one you expect:\n\n{1}\n\nSwitchDeck will remember it for next time.", "C'est la première connexion SSH à {0}. Vérifiez que l'empreinte de sa clé est bien celle attendue :\n\n{1}\n\nSwitchDeck la retiendra pour la suite." } },
            { "keyChangedTitle", new[] { "The switch key changed", "La clé du switch a changé" } },
            { "keyChangedText", new[] { "{0} answered with a different SSH key than last time. This is normal after a switch replacement or a new key, but it can also be a sign of an attack. Forget the old key and connect again?", "{0} a répondu avec une clé SSH différente de la dernière fois. C'est normal après un remplacement ou une nouvelle clé, mais cela peut aussi signaler une attaque. Oublier l'ancienne clé et se reconnecter ?" } },
            { "forgetKey", new[] { "Forget old key", "Oublier l'ancienne clé" } },
            { "passwordRejected", new[] { "The saved password was refused. Type it in the terminal or edit the switch.", "Le mot de passe enregistré a été refusé. Tapez-le dans le terminal ou modifiez le switch." } },
            { "connectingTo", new[] { "SwitchDeck: connecting to {0} ({1})", "SwitchDeck : connexion à {0} ({1})" } },
            { "connectFailed", new[] { "SwitchDeck: could not connect. {0}", "SwitchDeck : connexion impossible. {0}" } },
            { "connectionClosed", new[] { "SwitchDeck: connection closed.", "SwitchDeck : connexion fermée." } },
            { "connectionClosedWhy", new[] { "SwitchDeck: connection closed ({0}).", "SwitchDeck : connexion fermée ({0})." } },
            { "noSsh", new[] { "The Windows SSH client was not found. Add it in Settings, Apps, Optional features, OpenSSH Client.", "Le client SSH de Windows est introuvable. Ajoutez-le dans Paramètres, Applications, Fonctionnalités facultatives, Client OpenSSH." } },
            { "noAddress", new[] { "This switch has no address.", "Ce switch n'a pas d'adresse." } },
            { "notConnected", new[] { "The connection to the switch was lost.", "La connexion au switch a été perdue." } },
            { "noPrompt", new[] { "The switch did not show its prompt in time.", "Le switch n'a pas affiché son invite à temps." } },
            { "needEnable", new[] { "This switch needs an enable secret. Add it in the switch settings.", "Ce switch demande un mot de passe enable. Ajoutez-le dans les réglages du switch." } },
            { "enableRejected", new[] { "The enable secret was refused.", "Le mot de passe enable a été refusé." } },
            { "timeoutOn", new[] { "No answer from the switch after: {0}", "Pas de réponse du switch après : {0}" } },
            { "noConfigMode", new[] { "The switch did not enter configuration mode.", "Le switch n'est pas entré en mode configuration." } },
            { "noIfMode", new[] { "The switch did not open the interface.", "Le switch n'a pas ouvert l'interface." } },
            { "noPortsFound", new[] { "No ports were found in the switch answer.", "Aucun port trouvé dans la réponse du switch." } },
            { "detecting", new[] { "Reading the port list", "Lecture de la liste des ports" } },
            { "detectFailed", new[] { "Could not read the ports", "Impossible de lire les ports" } },
            { "portsDetected", new[] { "{0} ports detected and saved", "{0} ports détectés et enregistrés" } },
            { "statusUpdated", new[] { "Port status updated", "État des ports mis à jour" } },
            { "replacePortsTitle", new[] { "Replace the port list?", "Remplacer la liste des ports ?" } },
            { "replacePortsText", new[] { "This switch has {0} saved ports and the switch reports {1}. Replace the saved list with what the switch reports?", "Ce switch a {0} ports enregistrés et le switch en annonce {1}. Remplacer la liste par celle du switch ?" } },

            { "portsAskTitle", new[] { "Ports of {0}", "Ports de {0}" } },
            { "portsAskText", new[] { "SwitchDeck needs the list of ports to deploy templates. How do you want to add them?", "SwitchDeck a besoin de la liste des ports pour déployer des modèles. Comment voulez-vous les ajouter ?" } },
            { "portsAskDetect", new[] { "Detect automatically", "Détection automatique" } },
            { "portsAskDetectText", new[] { "SwitchDeck runs show interfaces status and saves every physical port.", "SwitchDeck lance show interfaces status et enregistre chaque port physique." } },
            { "portsAskManual", new[] { "Add them myself", "Les saisir moi-même" } },
            { "portsAskManualText", new[] { "Type them in the switch settings, with ranges like Gi1/0/1-48.", "Saisissez-les dans les réglages du switch, avec des plages comme Gi1/0/1-48." } },

            { "fieldName", new[] { "Name", "Nom" } },
            { "fieldGroup", new[] { "Group", "Groupe" } },
            { "fieldKind", new[] { "Connection", "Connexion" } },
            { "fieldAddress", new[] { "Address", "Adresse" } },
            { "fieldPort", new[] { "Port", "Port" } },
            { "fieldCom", new[] { "COM port", "Port COM" } },
            { "fieldBaud", new[] { "Speed", "Vitesse" } },
            { "fieldModel", new[] { "Model", "Modèle" } },
            { "fieldUser", new[] { "Username", "Utilisateur" } },
            { "fieldPassword", new[] { "Password", "Mot de passe" } },
            { "fieldEnable", new[] { "Enable secret", "Mot de passe enable" } },
            { "phName", new[] { "SW-CORE-01", "SW-COEUR-01" } },
            { "phGroup", new[] { "Building A", "Bâtiment A" } },
            { "phEnable", new[] { "Optional", "Facultatif" } },
            { "kindSerial", new[] { "Serial console", "Console série" } },
            { "kindDemo", new[] { "Lab switch", "Switch de test" } },
            { "demoTarget", new[] { "Simulated lab switch", "Switch de test simulé" } },
            { "legacySsh", new[] { "Older switch (legacy SSH)", "Switch ancien (SSH ancien)" } },
            { "legacyTip", new[] { "Turns on the older SSH algorithms that switches on IOS 12 and early IOS 15 still use.", "Active les anciens algorithmes SSH encore utilisés par les switchs en IOS 12 et premières IOS 15." } },
            { "ciscoDefault", new[] { "Cisco default", "Par défaut Cisco" } },
            { "serialHint", new[] { "8 data bits, no parity, 1 stop bit, no flow control.", "8 bits de données, sans parité, 1 bit d'arrêt, sans contrôle de flux." } },
            { "demoHint", new[] { "A simulated Catalyst for trying SwitchDeck safely.", "Un Catalyst simulé pour essayer SwitchDeck sans risque." } },
            { "resetLab", new[] { "Reset lab switch", "Réinitialiser" } },
            { "resetLabText", new[] { "The lab switch goes back to its factory configuration. Its saved configuration is erased.", "Le switch de test revient à sa configuration d'usine. Sa configuration enregistrée est effacée." } },
            { "loginTitle", new[] { "Login", "Identifiants" } },
            { "secretsHint", new[] { "Passwords are encrypted for your Windows account only.", "Les mots de passe sont chiffrés pour votre compte Windows uniquement." } },
            { "addPorts", new[] { "Add ports", "Ajouter des ports" } },
            { "addPortsHint", new[] { "Separate with commas. Ranges work: Gi1/0/1-48, Te1/1/1-4, Po1", "Séparez par des virgules. Les plages marchent : Gi1/0/1-48, Te1/1/1-4, Po1" } },
            { "badPorts", new[] { "Not understood: {0}", "Non compris : {0}" } },
            { "portsAdded", new[] { "{0} ports added", "{0} ports ajoutés" } },
            { "noPortsDialog", new[] { "Add ports above, or connect and let SwitchDeck detect them.", "Ajoutez des ports ci-dessus, ou connectez-vous et laissez SwitchDeck les détecter." } },
            { "noPortsShort", new[] { "No ports", "Aucun port" } },
            { "portCount", new[] { "{0} ports   {1}", "{0} ports   {1}" } },
            { "removeAll", new[] { "Remove all", "Tout retirer" } },
            { "removeAllText", new[] { "Remove the {0} saved ports from this switch?", "Retirer les {0} ports enregistrés de ce switch ?" } },
            { "noDescription", new[] { "No description", "Sans description" } },
            { "descriptionOf", new[] { "Description of {0}", "Description de {0}" } },
            { "descriptionHint", new[] { "Shown next to the port in SwitchDeck.", "Affichée à côté du port dans SwitchDeck." } },
            { "otherPorts", new[] { "Other", "Autres" } },
            { "trunk", new[] { "trunk", "trunk" } },

            { "searchTemplates", new[] { "Search templates", "Rechercher un modèle" } },
            { "newTemplate", new[] { "New template", "Nouveau modèle" } },
            { "newTemplateName", new[] { "New template", "Nouveau modèle" } },
            { "noTemplatesTitle", new[] { "No templates yet", "Aucun modèle" } },
            { "noTemplatesText", new[] { "Create one for each kind of port you set up.", "Créez-en un pour chaque type de port que vous configurez." } },
            { "noTemplatesBig", new[] { "A template is a named port configuration, like Wifi-Hotspot: trunk mode with VLAN 2.", "Un modèle est une configuration de port nommée, comme Wifi-Hotspot : mode trunk avec le VLAN 2." } },
            { "phTemplateName", new[] { "Template name", "Nom du modèle" } },
            { "phTemplateDesc", new[] { "What is this port for?", "À quoi sert ce port ?" } },
            { "commandsTitle", new[] { "Interface commands", "Commandes d'interface" } },
            { "commandsHint", new[] { "One command per line, as typed inside the interface. Use {{name}} for a value set on the right, and {{port}} for the port name. Lines starting with ! are notes.", "Une commande par ligne, comme dans l'interface. Utilisez {{nom}} pour une valeur réglée à droite, et {{port}} pour le nom du port. Les lignes commençant par ! sont des notes." } },
            { "resetFirst", new[] { "Reset the port before applying", "Réinitialiser le port avant" } },
            { "resetFirstTip", new[] { "Sends default interface first, so old settings do not stay behind.", "Envoie d'abord default interface, pour ne pas garder d'anciens réglages." } },
            { "unsaved", new[] { "Unsaved changes", "Modifications non enregistrées" } },
            { "deploy", new[] { "Deploy", "Déployer" } },
            { "variablesTitle", new[] { "Values", "Valeurs" } },
            { "variablesNone", new[] { "This template has no values to fill. Add {{name}} in a command to create one.", "Ce modèle n'a aucune valeur à remplir. Ajoutez {{nom}} dans une commande pour en créer une." } },
            { "variablesPortOnly", new[] { "Only {{port}} is used. It is filled with each port name.", "Seul {{port}} est utilisé. Il prend le nom de chaque port." } },
            { "defaultFor", new[] { "Default for {0}", "Valeur par défaut de {0}" } },
            { "phDefault", new[] { "Empty", "Vide" } },
            { "previewTitle", new[] { "Preview", "Aperçu" } },
            { "linesCount", new[] { "{0} commands", "{0} commandes" } },
            { "nameNeeded", new[] { "Give the template a name", "Donnez un nom au modèle" } },
            { "nameTaken", new[] { "Another template already has this name", "Un autre modèle porte déjà ce nom" } },
            { "commandsNeeded", new[] { "Add at least one command", "Ajoutez au moins une commande" } },
            { "checkCommands", new[] { "Check this command", "Vérifiez cette commande" } },
            { "badLineText", new[] { "\"{0}\" is not an interface command. SwitchDeck already enters and leaves the interface and configuration mode for you.", "\"{0}\" n'est pas une commande d'interface. SwitchDeck entre et sort déjà de l'interface et du mode configuration pour vous." } },
            { "saveAnyway", new[] { "Save anyway", "Enregistrer quand même" } },
            { "templateSaved", new[] { "{0} saved", "{0} enregistré" } },
            { "templateDeleted", new[] { "{0} deleted", "{0} supprimé" } },
            { "deleteTemplate", new[] { "Delete this template?", "Supprimer ce modèle ?" } },
            { "deleteTemplateText", new[] { "{0} will be deleted. Ports already configured with it keep their configuration.", "{0} sera supprimé. Les ports déjà configurés avec lui gardent leur configuration." } },
            { "unsavedTitle", new[] { "Unsaved changes", "Modifications non enregistrées" } },
            { "unsavedText", new[] { "{0} has changes that are not saved.", "{0} a des modifications non enregistrées." } },

            { "setupTitle", new[] { "Setup", "Préparation" } },
            { "fieldSwitch", new[] { "Switch", "Switch" } },
            { "fieldTemplate", new[] { "Template", "Modèle" } },
            { "pickSwitch", new[] { "Choose a switch", "Choisissez un switch" } },
            { "pickTemplate", new[] { "Choose a template", "Choisissez un modèle" } },
            { "hostConnected", new[] { "Connected", "Connecté" } },
            { "hostWillConnect", new[] { "SwitchDeck connects when you deploy", "SwitchDeck se connecte au déploiement" } },
            { "valuesTitle", new[] { "Values", "Valeurs" } },
            { "modeTitle", new[] { "How to send it", "Méthode d'envoi" } },
            { "modeRange", new[] { "Range", "Plage" } },
            { "modeSingle", new[] { "One by one", "Un par un" } },
            { "modeRangeHint", new[] { "Uses interface range, so all ports get the commands at once. Fastest.", "Utilise interface range : tous les ports reçoivent les commandes d'un coup. Le plus rapide." } },
            { "modeSingleHint", new[] { "Opens each port in turn. Slower, but a problem on one port does not stop the others.", "Ouvre chaque port l'un après l'autre. Plus lent, mais un problème sur un port n'arrête pas les autres." } },
            { "portVarSingle", new[] { "This template uses {{port}}, so it is sent one port at a time.", "Ce modèle utilise {{port}}, il est donc envoyé port par port." } },
            { "optionsTitle", new[] { "Safety", "Sécurité" } },
            { "optReset", new[] { "Reset ports first", "Réinitialiser les ports avant" } },
            { "optCheck", new[] { "Read current config first", "Lire la config actuelle avant" } },
            { "optCheckTip", new[] { "Saves each port's configuration before the change, so you can roll back from History.", "Garde la configuration de chaque port avant le changement, pour pouvoir revenir en arrière depuis l'historique." } },
            { "optBackup", new[] { "Back up the running config", "Sauvegarder la running config" } },
            { "optBackupTip", new[] { "Saves the full running configuration to the backups folder before changing anything.", "Enregistre toute la configuration dans le dossier des sauvegardes avant tout changement." } },
            { "optVerify", new[] { "Check the result after", "Vérifier le résultat après" } },
            { "optVerifyTip", new[] { "Reads each port again and checks that every command is in its configuration.", "Relit chaque port et vérifie que chaque commande est dans sa configuration." } },
            { "optWrite", new[] { "Save to startup config", "Enregistrer en startup config" } },
            { "optWriteTip", new[] { "Runs write memory at the end, so the change survives a reboot.", "Lance write memory à la fin, pour que le changement survive à un redémarrage." } },
            { "freePorts", new[] { "Free ports", "Ports libres" } },
            { "freePortsTip", new[] { "Selects the ports with nothing plugged in.", "Sélectionne les ports sur lesquels rien n'est branché." } },
            { "refreshStatusTip", new[] { "Read the live status of every port", "Lire l'état actuel de chaque port" } },
            { "noneSelected", new[] { "No port selected", "Aucun port sélectionné" } },
            { "selectedCount", new[] { "{0} selected", "{0} sélectionnés" } },
            { "unknownPorts", new[] { "Not on this switch: {0}", "Absent de ce switch : {0}" } },
            { "deployNoPorts", new[] { "This switch has no saved ports yet. Add them in its settings, or connect once and let SwitchDeck read them.", "Ce switch n'a pas encore de ports enregistrés. Ajoutez-les dans ses réglages, ou connectez-vous une fois pour que SwitchDeck les lise." } },
            { "goToSwitch", new[] { "Open the switch", "Ouvrir le switch" } },
            { "viewPreview", new[] { "Commands", "Commandes" } },
            { "viewResults", new[] { "Results", "Résultats" } },
            { "viewCommands", new[] { "Commands", "Commandes" } },
            { "viewTranscript", new[] { "Transcript", "Transcription" } },
            { "viewBefore", new[] { "Before and after", "Avant et après" } },
            { "previewPickSwitch", new[] { "Choose a switch to see the commands", "Choisissez un switch pour voir les commandes" } },
            { "previewPickTemplate", new[] { "Choose a template to see the commands", "Choisissez un modèle pour voir les commandes" } },
            { "previewPickPorts", new[] { "Select ports to see the commands", "Sélectionnez des ports pour voir les commandes" } },
            { "deployTo", new[] { "Deploy on {0} ports", "Déployer sur {0} ports" } },
            { "deployToOne", new[] { "Deploy on 1 port", "Déployer sur 1 port" } },
            { "deployAgain", new[] { "Deploy again", "Redéployer" } },
            { "fillValue", new[] { "Fill in {0}", "Remplissez {0}" } },
            { "confirmTitle", new[] { "Deploy now?", "Déployer maintenant ?" } },
            { "confirmText", new[] { "{0} will be applied to {1} ports on {2}:\n{3}\n\nSwitchDeck will type {4} commands.", "{0} sera appliqué à {1} ports sur {2} :\n{3}\n\nSwitchDeck tapera {4} commandes." } },
            { "confirmWrite", new[] { "The change is then saved to the startup configuration.", "Le changement sera ensuite enregistré dans la configuration de démarrage." } },
            { "noResultsTitle", new[] { "No results yet", "Pas encore de résultats" } },
            { "noResultsText", new[] { "They show up here while SwitchDeck deploys.", "Ils s'affichent ici pendant le déploiement." } },
            { "openHistory", new[] { "History", "Historique" } },
            { "rollback", new[] { "Roll back", "Revenir en arrière" } },
            { "newDeploy", new[] { "New", "Nouveau" } },
            { "doneSummary", new[] { "{0} done, {2} failed, {3} skipped", "{0} faits, {2} en échec, {3} ignorés" } },
            { "savedStartup", new[] { "Saved to startup", "Enregistré en startup" } },
            { "deployOk", new[] { "{0} deployed on {1} ports", "{0} déployé sur {1} ports" } },
            { "deployWarn", new[] { "Deployed, some ports need a look", "Déployé, certains ports sont à vérifier" } },
            { "deployFailed", new[] { "The deployment did not complete", "Le déploiement n'a pas abouti" } },
            { "deploying", new[] { "Deploying", "Déploiement" } },
            { "stepReady", new[] { "Waiting for the switch prompt", "Attente de l'invite du switch" } },
            { "stepBackup", new[] { "Backing up the running configuration", "Sauvegarde de la configuration" } },
            { "stepRead", new[] { "Reading {0} ({1} of {2})", "Lecture de {0} ({1} sur {2})" } },
            { "stepConfig", new[] { "Entering configuration mode", "Passage en mode configuration" } },
            { "stepRange", new[] { "Configuring {0} ({1} of {2})", "Configuration de {0} ({1} sur {2})" } },
            { "stepPort", new[] { "Configuring {0} ({1} of {2})", "Configuration de {0} ({1} sur {2})" } },
            { "stepEnd", new[] { "Leaving configuration mode", "Sortie du mode configuration" } },
            { "stepVerify", new[] { "Checking {0} ({1} of {2})", "Vérification de {0} ({1} sur {2})" } },
            { "stepWrite", new[] { "Saving to startup config", "Enregistrement en startup config" } },
            { "notVisible", new[] { "Not found in the running config:", "Introuvable dans la running config :" } },
            { "writeFailed", new[] { "write memory did not confirm.", "write memory n'a pas confirmé." } },

            { "searchHistory", new[] { "Switch, template or port", "Switch, modèle ou port" } },
            { "noHistoryTitle", new[] { "Nothing deployed yet", "Rien de déployé" } },
            { "noHistoryText", new[] { "Every deployment is listed here.", "Chaque déploiement est listé ici." } },
            { "noHistoryBig", new[] { "Each deployment is recorded here with its commands, the switch answers and the port configuration before and after.", "Chaque déploiement est enregistré ici avec ses commandes, les réponses du switch et la configuration des ports avant et après." } },
            { "goDeploy", new[] { "Go to Deploy", "Aller à Déployer" } },
            { "openBackup", new[] { "Backup", "Sauvegarde" } },
            { "clickDetails", new[] { "Double-click for details", "Double-clic pour le détail" } },
            { "before", new[] { "Before", "Avant" } },
            { "after", new[] { "After", "Après" } },
            { "emptyConfig", new[] { "Default configuration", "Configuration par défaut" } },
            { "notRead", new[] { "Not read", "Non lu" } },
            { "noTranscript", new[] { "No transcript was recorded.", "Aucune transcription enregistrée." } },
            { "deleteEntry", new[] { "Delete this entry?", "Supprimer cette entrée ?" } },
            { "deleteEntryText", new[] { "It is removed from History. Nothing changes on the switch.", "Elle sera retirée de l'historique. Rien ne change sur le switch." } },
            { "rollbackTitle", new[] { "Roll back these ports?", "Revenir en arrière sur ces ports ?" } },
            { "rollbackText", new[] { "{0} ports on {1} will be reset and get back the configuration they had before:\n{2}", "{0} ports sur {1} seront réinitialisés et retrouveront leur configuration d'avant :\n{2}" } },
            { "rollbackEmpty", new[] { "{0} ports had no configuration recorded before, so they go back to default.", "{0} ports n'avaient aucune configuration enregistrée : ils reviennent à la configuration par défaut." } },
            { "rollbackNoHost", new[] { "This switch is no longer in SwitchDeck.", "Ce switch n'est plus dans SwitchDeck." } },
            { "rollbackNothing", new[] { "Nothing to roll back", "Rien à annuler" } },
            { "rollbackOf", new[] { "Roll back of {0}", "Retour arrière de {0}" } },
            { "rollbackStarted", new[] { "Rolling back", "Retour arrière en cours" } },
            { "rollbackOk", new[] { "Ports rolled back", "Ports restaurés" } },
            { "rollbackIssues", new[] { "Roll back finished with issues, see History", "Retour arrière terminé avec des problèmes, voir l'historique" } },

            { "setAppearance", new[] { "Appearance", "Apparence" } },
            { "setTerminal", new[] { "Terminal", "Terminal" } },
            { "setDeploy", new[] { "Deploy defaults", "Déploiement par défaut" } },
            { "setFolders", new[] { "Folders", "Dossiers" } },
            { "stepSetup", new[] { "Setup", "Préparation" } },
            { "stepPorts", new[] { "Ports", "Ports" } },
            { "stepResults", new[] { "Results", "Résultats" } },
            { "continue", new[] { "Continue", "Continuer" } },
            { "closing", new[] { "Closing...", "Fermeture..." } },
            { "uninstalling", new[] { "Uninstalling...", "Désinstallation..." } },
            { "uninstall", new[] { "Uninstall", "Désinstaller" } },
            { "uninstallRow", new[] { "Uninstall SwitchDeck", "Désinstaller SwitchDeck" } },
            { "uninstallRowHint", new[] { "Removes SwitchDeck from this PC.", "Retire SwitchDeck de ce PC." } },
            { "uninstallTitle", new[] { "Uninstall SwitchDeck?", "Désinstaller SwitchDeck ?" } },
            { "uninstallText", new[] { "This removes the shortcuts, the cache and the installed copy in {0}, with its switches and templates. Export your templates first if you want to keep them.", "Cela retire les raccourcis, le cache et la copie installée dans {0}, avec ses switchs et modèles. Exportez vos modèles avant si vous voulez les garder." } },
            { "uninstallTextNoCopy", new[] { "This removes the shortcuts and the cache from this PC.", "Cela retire les raccourcis et le cache de ce PC." } },
            { "uninstallTextHere", new[] { "The folder you are running it from is not deleted: {0}", "Le dossier depuis lequel il est lancé n'est pas supprimé : {0}" } },
            { "installHereTitle", new[] { "Install on this PC (recommended)", "Installer sur ce PC (recommandé)" } },
            { "installHereText", new[] { "SwitchDeck is copied here, so you can delete the downloaded folder.", "SwitchDeck est copié ici, vous pourrez supprimer le dossier téléchargé." } },
            { "runHereTitle", new[] { "Run from this folder", "Lancer depuis ce dossier" } },
            { "runHereText", new[] { "Nothing is copied. Keep this folder where it is.", "Rien n'est copié. Gardez ce dossier à sa place." } },
            { "change", new[] { "Change", "Modifier" } },
            { "pickInstallFolder", new[] { "Where should SwitchDeck be installed?", "Où installer SwitchDeck ?" } },
            { "installFailed", new[] { "Could not install SwitchDeck", "Impossible d'installer SwitchDeck" } },
            { "welcomeInstallTitle", new[] { "Welcome to SwitchDeck", "Bienvenue dans SwitchDeck" } },
            { "welcomeInstallText", new[] { "Set up SwitchDeck on this PC", "Installer SwitchDeck sur ce PC" } },
            { "welcomeInstallHint", new[] { "Nothing is copied: the shortcuts open SwitchDeck from where it is now. You can change this later in Settings.", "Rien n'est copié : les raccourcis ouvrent SwitchDeck là où il se trouve. Vous pourrez changer cela plus tard dans les Paramètres." } },
            { "shortcutDesktop", new[] { "Shortcut on the desktop", "Raccourci sur le bureau" } },
            { "shortcutStart", new[] { "SwitchDeck in the Start menu", "SwitchDeck dans le menu Démarrer" } },
            { "setShortcuts", new[] { "This PC", "Ce PC" } },
            { "notNow", new[] { "Not now", "Pas maintenant" } },
            { "installOpen", new[] { "Install and open", "Installer et ouvrir" } },
            { "viewPorts", new[] { "Ports", "Ports" } },
            { "viewList", new[] { "List", "Liste" } },
            { "resultsLegend", new[] { "Green: applied. Red: failed, click it to see why.", "Vert : appliqué. Rouge : en échec, cliquez pour voir pourquoi." } },
            { "advancedOptions", new[] { "Advanced options", "Options avancées" } },
            { "back", new[] { "Back", "Retour" } },
            { "close", new[] { "Close", "Fermer" } },
            { "showCommands", new[] { "Commands", "Commandes" } },
            { "portsOf", new[] { "Ports of {0}", "Ports de {0}" } },
            { "resultsTitle", new[] { "{0} on {1}", "{0} sur {1}" } },
            { "otherPorts2", new[] { "Other ports", "Autres ports" } },
            { "quitOne", new[] { "A session is still open. Closing SwitchDeck disconnects it.", "Une session est encore ouverte. Fermer SwitchDeck la déconnecte." } },
            { "quitMany", new[] { "{0} sessions are still open. Closing SwitchDeck disconnects them.", "{0} sessions sont encore ouvertes. Fermer SwitchDeck les déconnecte." } },
            { "importExport", new[] { "Import and export", "Importer et exporter" } },
            { "exportThis", new[] { "Export this template", "Exporter ce modèle" } },
            { "exportAll", new[] { "Export all templates", "Exporter tous les modèles" } },
            { "importTemplates", new[] { "Import templates", "Importer des modèles" } },
            { "templateFiles", new[] { "SwitchDeck templates", "Modèles SwitchDeck" } },
            { "exportedOne", new[] { "{0} exported", "{0} exporté" } },
            { "exportedMany", new[] { "{0} templates exported", "{0} modèles exportés" } },
            { "importedTemplates", new[] { "{0} templates imported", "{0} modèles importés" } },
            { "notTemplateFile", new[] { "{0} is not a SwitchDeck file.", "{0} n'est pas un fichier SwitchDeck." } },
            { "missingValueTitle", new[] { "A value is missing", "Une valeur manque" } },
            { "missingValueText", new[] { "{0} has no value in the template {1}. Set it in the Templates tab, then deploy again.", "{0} n'a pas de valeur dans le modèle {1}. Renseignez-la dans l'onglet Modèles, puis redéployez." } },
            { "fieldPorts", new[] { "Ports", "Ports" } },
            { "portsFieldHint", new[] { "Ranges work, like Gi1/0/1-48, Te1/1/1-4. Leave empty and SwitchDeck offers to read them on the first connection.", "Les plages marchent, comme Gi1/0/1-48, Te1/1/1-4. Laissez vide et SwitchDeck proposera de les lire à la première connexion." } },
            { "passwordHint", new[] { "Also used as the enable secret.", "Sert aussi de mot de passe enable." } },
            { "demoPasswordHint", new[] { "Enable secret of the lab switch. The default is cisco.", "Mot de passe enable du switch de test. Par défaut : cisco." } },
            { "setData", new[] { "Switches and templates", "Switchs et modèles" } },
            { "exportTitle", new[] { "Export", "Exporter" } },
            { "exportHint", new[] { "Saves your switches and templates to one file, without any password. Handy for a backup or a colleague.", "Enregistre vos switchs et modèles dans un fichier, sans aucun mot de passe. Pratique pour une sauvegarde ou un collègue." } },
            { "exportData", new[] { "Export", "Exporter" } },
            { "importTitle", new[] { "Import", "Importer" } },
            { "importHint", new[] { "Adds the switches and templates from an export file. Nothing you already have is replaced.", "Ajoute les switchs et modèles d'un fichier d'export. Rien de ce que vous avez n'est remplacé." } },
            { "importData", new[] { "Import", "Importer" } },
            { "exported", new[] { "{0} switches and {1} templates exported", "{0} switchs et {1} modèles exportés" } },
            { "imported", new[] { "{0} switches and {1} templates added", "{0} switchs et {1} modèles ajoutés" } },
            { "importFailed", new[] { "This file could not be read", "Impossible de lire ce fichier" } },
            { "importNothing", new[] { "Everything in this file is already in SwitchDeck", "Tout ce fichier est déjà dans SwitchDeck" } },
            { "quickCommands", new[] { "Commands", "Commandes" } },
            { "writeTitle", new[] { "Save the configuration?", "Enregistrer la configuration ?" } },
            { "writeText", new[] { "write memory copies the running configuration of {0} to its startup configuration.", "write memory copie la configuration en cours de {0} dans sa configuration de démarrage." } },
            { "writeNow", new[] { "Save it", "Enregistrer" } },
            { "imported2", new[] { "imported", "importé" } },
            { "language", new[] { "Language", "Langue" } },
            { "theme", new[] { "Theme", "Thème" } },
            { "light", new[] { "Light", "Clair" } },
            { "system", new[] { "System", "Système" } },
            { "dark", new[] { "Dark", "Sombre" } },
            { "followTheme", new[] { "Same as app", "Comme l'appli" } },
            { "termColors", new[] { "Terminal colors", "Couleurs du terminal" } },
            { "termColorsHint", new[] { "A dark terminal is easier to read for long sessions.", "Un terminal sombre est plus reposant sur de longues sessions." } },
            { "termSize", new[] { "Terminal text size", "Taille du texte" } },
            { "termSizeHint", new[] { "Ctrl + and Ctrl - also work inside the terminal.", "Ctrl + et Ctrl - marchent aussi dans le terminal." } },
            { "copyOnSelect", new[] { "Copy on select", "Copier à la sélection" } },
            { "copyOnSelectHint", new[] { "Selected text goes straight to the clipboard, like PuTTY.", "Le texte sélectionné va directement dans le presse-papiers, comme PuTTY." } },
            { "rightPaste", new[] { "Right-click pastes", "Clic droit pour coller" } },
            { "rightPasteHint", new[] { "Ctrl + right-click opens the menu instead.", "Ctrl + clic droit ouvre le menu à la place." } },
            { "sessionLogs", new[] { "Save session logs", "Enregistrer les sessions" } },
            { "sessionLogsHint", new[] { "Keeps a text file of every terminal session in the logs folder.", "Garde un fichier texte de chaque session dans le dossier des journaux." } },
            { "defaultUser", new[] { "Default username", "Utilisateur par défaut" } },
            { "defaultUserHint", new[] { "Filled in when you add a switch.", "Prérempli à l'ajout d'un switch." } },
            { "defaultMode", new[] { "Default method", "Méthode par défaut" } },
            { "defaultModeHint", new[] { "Range is faster, one by one is safer.", "La plage est plus rapide, un par un plus sûr." } },
            { "confirmDeploy", new[] { "Ask before deploying", "Demander avant de déployer" } },
            { "confirmDeployHint", new[] { "Shows a summary of what will change.", "Affiche un résumé de ce qui va changer." } },
            { "lineDelay", new[] { "Pause between commands", "Pause entre les commandes" } },
            { "lineDelayHint", new[] { "Helps slow serial links and busy switches.", "Aide sur les liaisons série lentes et les switchs chargés." } },
            { "logsFolder", new[] { "Logs", "Journaux" } },
            { "sessionLogsFolder", new[] { "Session logs", "Sessions" } },
            { "backupsFolder", new[] { "Backups", "Sauvegardes" } },
            { "dataFolder", new[] { "Data", "Données" } },

            { "version", new[] { "Version {0}", "Version {0}" } },
            { "about", new[] { "Connect to your Cisco switches and push saved port templates in a few clicks.", "Connectez-vous à vos switchs Cisco et déployez des modèles de port en quelques clics." } },
            { "feat1", new[] { "SSH, serial console and a lab switch for practice", "SSH, console série et un switch de test pour s'entraîner" } },
            { "feat2", new[] { "A terminal with copy on select and right-click paste", "Un terminal avec copie à la sélection et collage au clic droit" } },
            { "feat3", new[] { "Port templates you write once and reuse", "Des modèles de port écrits une fois et réutilisés" } },
            { "feat4", new[] { "Deploy on a range of ports or one port at a time", "Déploiement sur une plage de ports ou port par port" } },
            { "createdBy", new[] { "Created by Luka LAURENT", "Créé par Luka LAURENT" } },

            { "sampleGroup", new[] { "Lab", "Labo" } },
            { "sampleWifi", new[] { "Wifi access point, trunk with the Wifi VLAN", "Borne Wifi, trunk avec le VLAN Wifi" } },
            { "sampleOffice", new[] { "Desk PC in the office VLAN", "PC de bureau dans le VLAN bureautique" } },
            { "samplePhone", new[] { "IP phone with a PC behind it", "Téléphone IP avec un PC derrière" } },
            { "samplePrinter", new[] { "Network printer, named after its port", "Imprimante réseau, nommée d'après son port" } },
            { "sampleUnused", new[] { "Parked and shut down", "Mis de côté et éteint" } },
        };

        public static string T(string key)
        {
            string[] v;
            if (!texts.TryGetValue(key, out v)) return key;
            return Lang == "fr" ? v[1] : v[0];
        }

        public static string F(string key, params object[] args)
        {
            try { return string.Format(CultureInfo.CurrentCulture, T(key), args); }
            catch (FormatException) { return T(key); }
        }

        public static bool Has(string key) { return texts.ContainsKey(key); }

        public static string StatusText(string status)
        {
            bool fr = Lang == "fr";
            switch (status)
            {
                case "connected": return fr ? "Branché" : "Connected";
                case "notconnect": return fr ? "Rien de branché" : "Nothing plugged in";
                case "disabled": return fr ? "Éteint (shutdown)" : "Shut down";
                case "err-disabled": return fr ? "Bloqué (err-disabled)" : "Blocked (err-disabled)";
                case "inactive": return fr ? "Inactif" : "Inactive";
                default: return status;
            }
        }

        public static string ResultText(string result)
        {
            bool fr = Lang == "fr";
            switch (result)
            {
                case "ok": return fr ? "Appliqué" : "Applied";
                case "warn": return fr ? "À vérifier" : "Check it";
                case "failed": return fr ? "Échec" : "Failed";
                case "running": return fr ? "En cours" : "In progress";
                case "applied": return fr ? "Envoyé" : "Sent";
                case "skipped": return fr ? "Ignoré" : "Skipped";
                case "pending": return fr ? "En attente" : "Waiting";
                default: return result;
            }
        }

        public static string Pretty(string variable)
        {
            string s = variable.Replace('_', ' ').Replace('-', ' ').Trim();
            if (s.Length == 0) return variable;
            s = s.Replace("vlan", "VLAN").Replace("Vlan", "VLAN");
            return char.ToUpper(s[0], CultureInfo.CurrentCulture) + s.Substring(1);
        }

        public static string IconName(string icon)
        {
            bool fr = Lang == "fr";
            switch (icon)
            {
                case "settings_ethernet": return fr ? "Port" : "Port";
                case "wifi": return "Wifi";
                case "call": return fr ? "Téléphone" : "Phone";
                case "computer": return "PC";
                case "print": return fr ? "Imprimante" : "Printer";
                case "videocam": return fr ? "Caméra" : "Camera";
                case "lan": return fr ? "Réseau" : "Network";
                case "hub": return "Hub";
                case "router": return "Switch";
                case "dns": return fr ? "Serveur" : "Server";
                case "security": return fr ? "Sécurité" : "Security";
                case "block": return fr ? "Bloqué" : "Blocked";
                case "power_off": return fr ? "Éteint" : "Off";
                case "sensors": return fr ? "Capteur" : "Sensor";
                case "devices": return fr ? "Appareils" : "Devices";
                case "storage": return fr ? "Stockage" : "Storage";
                default: return icon;
            }
        }
    }
}
