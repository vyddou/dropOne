import consumer from "channels/consumer"

// Variables globales pour tracker les notifications
let hasNewActivities = false
let unreadMessagesCount = 0
let originalTitle = "DropOne"

consumer.subscriptions.create("NotificationsChannel", {
  connected() {
    console.log("Connected to notifications channel")
    // Initialiser le titre au chargement
    this.initializeNotifications()
  },

  disconnected() {
    console.log("Disconnected from notifications channel")
  },

  received(data) {
    console.log("Received notification:", data)
    
    if (data.type === 'activity') {
      hasNewActivities = true
      this.updateActivityNotification(true)
    } else if (data.type === 'message') {
      unreadMessagesCount = data.count
      this.updateMessageNotification(data.count)
    }
    
    // Mettre à jour le titre de la page
    this.updatePageTitle()
  },

  initializeNotifications() {
    // Sauvegarder le titre original
    originalTitle = document.title.replace(/^\(\d+\)\s/, '')
    
    // Vérifier s'il y a des notifications existantes au chargement
    const heartIcon = document.querySelector('.bi-suit-heart')
    const messageIcon = document.querySelector('.bi-chat-dots-fill')
    
    let totalNotifications = 0
    
    if (heartIcon && heartIcon.parentElement) {
      const heartBadge = heartIcon.parentElement.querySelector('.bg-danger')
      if (heartBadge) {
        hasNewActivities = true
        totalNotifications += 1
      }
    }
    
    if (messageIcon && messageIcon.parentElement) {
      const messageBadge = messageIcon.parentElement.querySelector('.badge')
      if (messageBadge) {
        unreadMessagesCount = parseInt(messageBadge.textContent) || 0
        totalNotifications += unreadMessagesCount
      }
    }
    
    // Mettre à jour le titre si nécessaire
    if (totalNotifications > 0) {
      document.title = `(${totalNotifications}) ${originalTitle}`
    }
  },

  updateActivityNotification(hasNew) {
    const heartIcon = document.querySelector('.bi-suit-heart')
    if (!heartIcon || !heartIcon.parentElement) return
    
    const existingBadge = heartIcon.parentElement.querySelector('.bg-danger')
    
    if (hasNew && !existingBadge) {
      const badge = document.createElement('span')
      badge.className = 'position-absolute top-0 start-100 translate-middle p-1 bg-danger border border-light rounded-circle'
      badge.innerHTML = '<span class="visually-hidden">Nouvelles activités</span>'
      heartIcon.parentElement.appendChild(badge)
    }
  },

  updateMessageNotification(count) {
    const messageIcon = document.querySelector('.bi-chat-dots-fill')
    if (!messageIcon || !messageIcon.parentElement) return
    
    const existingBadge = messageIcon.parentElement.querySelector('.badge')
    
    if (count > 0) {
      if (existingBadge) {
        existingBadge.textContent = count
      } else {
        const badge = document.createElement('span')
        badge.className = 'position-absolute top-0 start-100 translate-middle badge rounded-pill bg-danger'
        badge.textContent = count
        messageIcon.parentElement.appendChild(badge)
      }
    } else if (existingBadge) {
      existingBadge.remove()
    }
  },

  updatePageTitle() {
    const totalNotifications = (hasNewActivities ? 1 : 0) + unreadMessagesCount
    
    if (totalNotifications > 0) {
      document.title = `(${totalNotifications}) ${originalTitle}`
    } else {
      document.title = originalTitle
    }
  }
})

// Réinitialiser les notifications quand on visite les pages correspondantes
document.addEventListener('turbo:load', () => {
  const currentPath = window.location.pathname
  
  // Si on visite la page d'activités, marquer comme vu
  if (currentPath.includes('/activity')) {
    hasNewActivities = false
    const heartIcon = document.querySelector('.bi-suit-heart')
    if (heartIcon && heartIcon.parentElement) {
      const badge = heartIcon.parentElement.querySelector('.bg-danger')
      if (badge) badge.remove()
    }
    
    // Mettre à jour le titre
    const totalNotifications = unreadMessagesCount
    if (totalNotifications > 0) {
      document.title = `(${totalNotifications}) ${originalTitle}`
    } else {
      document.title = originalTitle
    }
  }
})