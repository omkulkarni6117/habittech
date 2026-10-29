```python
class Node:
    def __init__(self, city, population):
        self.city = city
        self.population = population
        self.left = None
        self.right = None


class CityBST:
    def __init__(self):
        self.root = None

    # Insert city (updates population if the city already exists)
    def insert(self, root, city, population):
        if root is None:
            return Node(city, population)
        if city < root.city:
            root.left = self.insert(root.left, city, population)
        elif city > root.city:
            root.right = self.insert(root.right, city, population)
        else:
            root.population = population
        return root

    # Search city (with comparison count)
    def search(self, root, city):
        comparisons = 0
        current = root
        while current:
            comparisons += 1
            if city == current.city:
                return current, comparisons
            elif city < current.city:
                current = current.left
            else:
                current = current.right
        return None, comparisons

    # Smallest node in a subtree
    def min_value_node(self, node):
        current = node
        while current.left:
            current = current.left
        return current

    # Delete city
    def delete(self, root, city):
        if root is None:
            return root
        if city < root.city:
            root.left = self.delete(root.left, city)
        elif city > root.city:
            root.right = self.delete(root.right, city)
        else:
            if root.left is None:
                return root.right
            elif root.right is None:
                return root.left
            temp = self.min_value_node(root.right)
            root.city, root.population = temp.city, temp.population
            root.right = self.delete(root.right, temp.city)
        return root

    # Update population
    def update_population(self, root, city, new_population):
        node, _ = self.search(root, city)
        if node:
            node.population = new_population
            print(f"Population of {city} updated to {new_population}")
        else:
            print(f"City {city} not found!")

    # Ascending order (inorder)
    def display_ascending(self, root):
        if root:
            self.display_ascending(root.left)
            print(f"{root.city}: {root.population}")
            self.display_ascending(root.right)

    # Descending order (reverse inorder)
    def display_descending(self, root):
        if root:
            self.display_descending(root.right)
            print(f"{root.city}: {root.population}")
            self.display_descending(root.left)

    # City with maximum population (full traversal)
    def max_population_city(self, root):
        if root is None:
            return None
        max_city = root
        stack = [root]
        while stack:
            node = stack.pop()
            if node.population > max_city.population:
                max_city = node
            if node.left:
                stack.append(node.left)
            if node.right:
                stack.append(node.right)
        return max_city


def read_int(prompt):
    while True:
        try:
            return int(input(prompt))
        except ValueError:
            print("Please enter a valid number.")


def read_city(prompt):
    return input(prompt).strip().lower()


# ---------------- Main Program ----------------
if __name__ == "__main__":
    bst = CityBST()

    while True:
        print("\n--- City Population BST Menu ---")
        print("1. Add/Insert City")
        print("2. Delete City")
        print("3. Update Population")
        print("4. Search City")
        print("5. Display Cities Ascending")
        print("6. Display Cities Descending")
        print("7. Show City with Maximum Population")
        print("8. Exit")

        choice = read_int("Enter choice: ")

        if choice == 1:
            city = read_city("Enter city name: ")
            pop = read_int("Enter population: ")
            bst.root = bst.insert(bst.root, city, pop)

        elif choice == 2:
            city = read_city("Enter city to delete: ")
            node, _ = bst.search(bst.root, city)
            if node:
                bst.root = bst.delete(bst.root, city)
                print(f"City {city} deleted.")
            else:
                print(f"City {city} not found!")

        elif choice == 3:
            city = read_city("Enter city name: ")
            pop = read_int("Enter new population: ")
            bst.update_population(bst.root, city, pop)

        elif choice == 4:
            city = read_city("Enter city to search: ")
            node, comps = bst.search(bst.root, city)
            if node:
                print(f"City {city} found with population {node.population}")
            else:
                print(f"City {city} not found!")
            print(f"Comparisons made: {comps}")

        elif choice == 5:
            print("Cities in Ascending Order:")
            bst.display_ascending(bst.root)

        elif choice == 6:
            print("Cities in Descending Order:")
            bst.display_descending(bst.root)

        elif choice == 7:
            max_city = bst.max_population_city(bst.root)
            if max_city:
                print(f"City with maximum population: {max_city.city} ({max_city.population})")
            else:
                print("No cities in the list!")

        elif choice == 8:
            print("Exiting program...")
            break

        else:
            print("Invalid choice! Try again.")
```
