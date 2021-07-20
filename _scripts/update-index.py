import os

first=True
with open('./docs/index.md', 'w') as f:
    f.write('# mongodb-vapor Documentation Index\n')

    for dir in sorted(os.listdir('./docs'), reverse=True):
        if not dir[0].isdigit():
            continue

        version_str = dir
        if first and "beta" not in dir:
            version_str += ' (current)'
            dir = 'current'
            first = False

        f.write('- [{}]({}/index.html)\n'.format(version_str, dir))
