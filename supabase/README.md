# Mettre en ligne This is My Beers

Le jeu fonctionne déjà sans serveur : la partie est sauvegardée dans le navigateur de chaque joueur. Supabase ne sert qu'aux **classements entre collègues** :

- **bars** : le chiffre d'affaires cumulé de chaque My Beers (mode gestion) ;
- **arcade_scores** : les meilleurs scores du mode Arcade (même jeu pour tous, sans amélioration).

## 1. Créer la base (5 minutes)

1. Crée un projet gratuit sur [supabase.com](https://supabase.com).
2. Ouvre **SQL Editor**, colle le contenu de `schema.sql` et clique sur **Run**.
3. Dans **Project Settings → API**, copie :
   - l'**URL du projet** (`https://xxxx.supabase.co`) ;
   - la clé **anon public**.

## 2. Brancher le jeu

Dans `index.html`, cherche la ligne :

```js
const CLOUD = { url: '', anonKey: '' };
```

et remplis-la :

```js
const CLOUD = { url: 'https://xxxx.supabase.co', anonKey: 'eyJhbGciOi…' };
```

L'onglet **🏆 Rang** du lobby affiche alors le top 50 des bars, et l'écran de fin du mode Arcade affiche le top 20 général. Les données sont envoyées après chaque soirée.

## 3. Héberger les fichiers

Il suffit de publier ces fichiers tels quels :

```
index.html
vendor/   (Three.js et les polices)
```

N'importe quel hébergement statique convient, par exemple Netlify (glisser-déposer le dossier), Vercel ou GitHub Pages. Partage ensuite le lien à tes collègues : ça marche directement sur téléphone.

## À savoir avant de partager

- **Pas de comptes** : un joueur = un appareil. S'il change de téléphone ou vide son navigateur, il repart de zéro.
- **Pas d'anti-triche** : la clé « anon » est publique par nature, donc un petit malin peut modifier son chiffre d'affaires. Pour un jeu entre collègues, ce n'est pas grave. Si ça le devient, la prochaine étape est d'ajouter la connexion anonyme Supabase (`signInAnonymously`) et de restreindre la mise à jour à la ligne du joueur.
